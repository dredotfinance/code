// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AppAccessControlled.sol";
import "../interfaces/IAppStaking.sol";
import "../interfaces/IApp.sol";
import "../interfaces/IAppBondDepository.sol";
import "../interfaces/IAppTreasury.sol";

/// @title RZR Bond Depository
/// @author RZR Protocol
/// @notice Implementation of the bond depository system that allows users to purchase bonds with quote tokens
/// @dev This contract handles bond creation, management, and NFT-based bond positions
contract AppBondDepository is
    AppAccessControlled,
    ERC721EnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    IAppBondDepository
{
    using SafeERC20 for IERC20;

    uint256 public immutable BASIS_POINTS = 10000; // 100%

    /// @inheritdoc IAppBondDepository
    uint256 public immutable override VESTING_PERIOD = 12 days;

    /// @inheritdoc IAppBondDepository
    uint256 public immutable override STAKING_LOCK_PERIOD = 30 days;

    // Storage
    Bond[] private _bonds;
    mapping(uint256 => BondPosition) private _positions;

    /// @inheritdoc IAppBondDepository
    IAppStaking public override staking;

    /// @inheritdoc IAppBondDepository
    IApp public override app;

    /// @inheritdoc IAppBondDepository
    IAppTreasury public override treasury;

    /// @inheritdoc IAppBondDepository
    uint256 public override lastId = 1;

    /// @inheritdoc IAppBondDepository
    mapping(uint256 => bool) public override blacklisted;

    /// @inheritdoc IAppBondDepository
    function initialize(address _app, address _staking, address _treasury, address _authority)
        public
        override
        reinitializer(2)
    {
        __ERC721_init("RZR Bond Position", "RZR-BOND");
        __ReentrancyGuard_init();
        __AppAccessControlled_init(_authority);
        staking = IAppStaking(_staking);
        treasury = IAppTreasury(_treasury);
        app = IApp(_app);
        if (lastId == 0) lastId = 1;
    }

    /// @inheritdoc IAppBondDepository
    function bonds(uint256 index) external view override returns (Bond memory bond) {
        bond = _bonds[index];
    }

    /// @inheritdoc IAppBondDepository
    function positions(uint256 tokenId) external view override returns (BondPosition memory position) {
        position = _positions[tokenId];
    }

    /* ======== MUTATIVE FUNCTIONS ======== */

    /// @inheritdoc IAppBondDepository
    function create(
        IERC20 _quoteToken,
        uint256 _capacity,
        uint256 _initialPrice,
        uint256 _finalPrice,
        uint256 _duration
    ) external override onlyBondManager returns (uint256 id_) {
        require(_initialPrice > _finalPrice, "Invalid price range");
        require(_duration > 0, "Invalid duration");

        id_ = _bonds.length;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + _duration;

        _bonds.push(
            Bond({
                enabled: true,
                capacity: _capacity,
                quoteToken: _quoteToken,
                totalDebt: 0,
                maxPayout: _capacity,
                sold: 0,
                purchased: 0,
                startTime: startTime,
                endTime: endTime,
                initialPrice: _initialPrice,
                finalPrice: _finalPrice
            })
        );

        emit CreateBond(id_, address(_quoteToken), _initialPrice, _capacity);
        _quoteToken.approve(address(treasury), type(uint256).max);
    }

    /// @inheritdoc IAppBondDepository
    function deposit(uint256 _id, uint256 _amount, uint256 _maxPrice, uint256 _minPayout, address _user)
        external
        override
        nonReentrant
        returns (uint256 payout_, uint256 tokenId_)
    {
        Bond storage bond = _bonds[_id];
        require(block.timestamp < bond.endTime, "Bond ended");
        require(bond.enabled, "Bond not enabled");
        require(bond.capacity > 0, "Bond full");
        require(_amount > 0, "Amount too small");

        // Calculate current price based on time elapsed
        uint256 currentPrice_ = _currentPrice(_id);
        require(currentPrice_ <= _maxPrice, "Price too high");

        // Calculate payout
        uint256 profit_;
        (payout_, profit_) = _calculatePayoutAndProfit(bond.quoteToken, currentPrice_, _amount);
        require(payout_ <= bond.maxPayout, "Amount too large");
        require(payout_ >= _minPayout, "Slippage too high");
        require(payout_ > 0, "Payout too small");

        // Update bond state
        bond.capacity -= payout_;
        bond.purchased += _amount;
        bond.sold += payout_;
        bond.totalDebt += payout_;

        // Transfer tokens
        bond.quoteToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Deposit to treasury and mint RZR tokens
        treasury.deposit(_amount, address(bond.quoteToken), profit_);

        // Create bond position NFT
        tokenId_ = lastId++;
        _mint(_user, tokenId_);

        _positions[tokenId_] = BondPosition({
            bondId: _id,
            amount: payout_,
            quoteAmount: _amount,
            startTime: block.timestamp,
            lastClaimTime: block.timestamp,
            claimedAmount: 0,
            isStaked: false
        });

        emit BondCreated(_id, _amount, currentPrice_);
    }

    /// @inheritdoc IAppBondDepository
    function claim(uint256 _tokenId) external override nonReentrant {
        address owner = ownerOf(_tokenId);
        require(!blacklisted[_tokenId], "blacklisted");
        BondPosition storage position = _positions[_tokenId];
        require(!position.isStaked, "Position is staked");

        uint256 claimable = _claimableAmount(_tokenId);
        require(claimable > 0, "Nothing to claim");

        position.claimedAmount += claimable;
        position.lastClaimTime = block.timestamp;

        app.transfer(owner, claimable);

        emit Claimed(_tokenId, claimable);
    }

    /// @inheritdoc IAppBondDepository
    function stake(uint256 _tokenId, uint256 _declaredValue) external override nonReentrant {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        require(!blacklisted[_tokenId], "blacklisted");
        BondPosition storage position = _positions[_tokenId];
        require(!position.isStaked, "Already staked");

        uint256 claimable = position.amount - position.claimedAmount;
        require(claimable > 0, "Nothing to stake");

        position.isStaked = true;
        position.claimedAmount += claimable;

        // Approve and stake tokens with 30 day minimum lock
        app.approve(address(staking), claimable);
        staking.createPosition(msg.sender, claimable, _declaredValue, block.timestamp + STAKING_LOCK_PERIOD);

        emit Staked(_tokenId, claimable);
    }

    function updateBond(uint256 _id, uint256 _capacity, uint256 _maxPayout, uint256 _initialPrice, uint256 _finalPrice)
        external
        onlyBondManager
    {
        _bonds[_id].capacity = _capacity;
        _bonds[_id].maxPayout = _maxPayout;
        _bonds[_id].initialPrice = _initialPrice;
        _bonds[_id].finalPrice = _finalPrice;
        emit UpdateBond(_id, _capacity, _maxPayout, _initialPrice, _finalPrice);
    }

    /* ======== VIEW FUNCTIONS ======== */

    /// @notice Calculates the current price of a bond based on time elapsed
    /// @param _id The ID of the bond
    /// @return The current price in quote token
    function _currentPrice(uint256 _id) internal view returns (uint256) {
        Bond memory bond = _bonds[_id];
        if (block.timestamp >= bond.endTime) return bond.finalPrice;

        uint256 timeElapsed = block.timestamp - bond.startTime;
        uint256 duration = bond.endTime - bond.startTime;

        return bond.initialPrice - ((bond.initialPrice - bond.finalPrice) * timeElapsed) / duration;
    }

    /// @notice Calculates the amount of tokens that can be claimed from a bond position
    /// @param _tokenId The ID of the bond position
    /// @return The amount of tokens that can be claimed
    function _claimableAmount(uint256 _tokenId) internal view returns (uint256) {
        BondPosition memory position = _positions[_tokenId];
        if (position.claimedAmount >= position.amount) return 0;

        uint256 timeElapsed = block.timestamp - position.startTime;
        if (timeElapsed >= VESTING_PERIOD) {
            return position.amount - position.claimedAmount;
        }

        uint256 vestedAmount = (position.amount * timeElapsed) / VESTING_PERIOD;
        return vestedAmount - position.claimedAmount;
    }

    /// @notice Disables a bond, preventing further deposits
    /// @param _id The ID of the bond to disable
    function disable(uint256 _id) external onlyBondManager {
        _bonds[_id].enabled = false;
        emit DisableBond(_id);
    }

    /// @inheritdoc IAppBondDepository
    function isLive(uint256 _id) external view override returns (bool) {
        Bond memory bond = _bonds[_id];
        return block.timestamp < bond.endTime && bond.capacity > 0;
    }

    /// @inheritdoc IAppBondDepository
    function currentPrice(uint256 _id) external view override returns (uint256) {
        return _currentPrice(_id);
    }

    /// @inheritdoc IAppBondDepository
    function claimableAmount(uint256 _tokenId) external view override returns (uint256) {
        return _claimableAmount(_tokenId);
    }

    /// @inheritdoc IAppBondDepository
    function getBond(uint256 _id) external view override returns (Bond memory) {
        return _bonds[_id];
    }

    /// @inheritdoc IAppBondDepository
    function bondLength() external view override returns (uint256) {
        return _bonds.length;
    }

    /// @inheritdoc IAppBondDepository
    function toggleBlacklist(uint256 _id) external onlyGuardian {
        require(_id < _bonds.length, "Invalid bond ID");
        blacklisted[_id] = !blacklisted[_id];
        emit Blacklisted(_id, blacklisted[_id]);
    }

    /// @notice Calculates the payout and profit for a given token, price, and amount
    /// @param _token The token to calculate the payout and profit for
    /// @param _price The price of the token
    /// @param _amount The amount of tokens to calculate the payout and profit for
    /// @return payout The payout amount
    /// @return profit The profit amount
    function calculatePayoutAndProfit(IERC20 _token, uint256 _price, uint256 _amount)
        external
        view
        returns (uint256 payout, uint256 profit)
    {
        return _calculatePayoutAndProfit(_token, _price, _amount);
    }

    /// @notice Returns the base URI for the NFT metadata
    /// @return The base URI string
    function _baseURI() internal view virtual override returns (string memory) {
        return "https://uri.rezerve.money/api/bonds/";
    }

    function _calculatePayoutAndProfit(IERC20 _token, uint256 _price, uint256 _amount)
        internal
        view
        returns (uint256 payout, uint256 profit)
    {
        payout = (_amount * 1e18) / _price;

        uint256 fee = _amount * treasury.reserveFee() / BASIS_POINTS;
        uint256 expectedPayout = treasury.tokenValueE18(address(_token), _amount - fee);

        if (expectedPayout > payout) {
            profit = expectedPayout - payout;
        }
    }
}
