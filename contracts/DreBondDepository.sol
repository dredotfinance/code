// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.15;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./DreAccessControlled.sol";
import "./interfaces/IDreStaking.sol";
import "./interfaces/IDRE.sol";
import "./interfaces/IDreBondDepository.sol";
import "./interfaces/IDreTreasury.sol";

/// @title DRE Bond Depository
/// @author DRE Protocol
contract DreBondDepository is
    DreAccessControlled,
    ERC721EnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    IDreBondDepository
{
    using SafeERC20 for IERC20;

    // Constants
    uint256 public immutable override VESTING_PERIOD = 12 days;
    uint256 public immutable override STAKING_LOCK_PERIOD = 30 days;
    uint256 public immutable override BASIS_POINTS = 10000;
    uint256 public immutable override TEAM_SHARE = 500; // 5%

    // Storage
    Bond[] private _bonds;
    IDreStaking public override staking;
    IDRE public override dre;
    IDreTreasury public override treasury;
    mapping(uint256 => BondPosition) private _positions;
    uint256 public override lastId = 1;

    function initialize(address _dre, address _staking, address _treasury, address _authority)
        public
        override
        reinitializer(3)
    {
        __ERC721_init("DRE Bond Position", "DRE-BOND");
        __ReentrancyGuard_init();
        __DreAccessControlled_init(_authority);
        staking = IDreStaking(_staking);
        treasury = IDreTreasury(_treasury);
        dre = IDRE(_dre);
        if (lastId == 0) lastId = 1;
    }

    function bonds(uint256 index) external view override returns (Bond memory bond) {
        bond = _bonds[index];
    }

    function positions(uint256 tokenId) external view override returns (BondPosition memory position) {
        position = _positions[tokenId];
    }

    /* ======== MUTATIVE FUNCTIONS ======== */

    /**
     * @notice creates a new bond
     * @param _quoteToken token used to deposit
     * @param _capacity total capacity of the bond
     * @param _initialPrice starting price in quote token
     * @param _finalPrice ending price in quote token
     * @param _duration duration of the bond in seconds
     * @return id_ ID of new bond
     */
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
    }

    /**
     * @notice deposit quote tokens in exchange for a bond
     * @param _id ID of the bond
     * @param _amount amount of quote token to spend
     * @param _maxPrice maximum price willing to pay
     * @param _minPayout minimum payout required
     * @param _user recipient of the bond
     * @return payout_ amount of DRE tokens
     * @return tokenId_ ID of the bond position NFT
     */
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

        // Calculate current price based on time elapsed
        uint256 currentPrice_ = _currentPrice(_id);
        require(currentPrice_ <= _maxPrice, "Price too high");

        // Calculate payout
        payout_ = (_amount * 1e18) / currentPrice_;
        require(payout_ <= bond.maxPayout, "Amount too large");
        require(payout_ >= _minPayout, "Slippage too high");

        // Update bond state
        bond.capacity -= payout_;
        bond.purchased += _amount;
        bond.sold += payout_;
        bond.totalDebt += payout_;

        // Calculate fees
        uint256 teamFee = (_amount * TEAM_SHARE) / BASIS_POINTS;
        uint256 protocolAmount = _amount - teamFee;

        // Transfer tokens
        bond.quoteToken.safeTransferFrom(msg.sender, address(this), _amount);
        bond.quoteToken.safeTransfer(authority.operationsTreasury(), teamFee);

        // Deposit to treasury and mint DRE tokens
        bond.quoteToken.safeTransfer(address(treasury), protocolAmount);
        uint256 mintedAmount = treasury.tokenValueE18(address(bond.quoteToken), protocolAmount);
        dre.mint(address(this), mintedAmount);

        // Create bond position NFT
        tokenId_ = lastId++;
        _safeMint(_user, tokenId_);

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

    /**
     * @notice claim vested tokens from a bond position
     * @param _tokenId ID of the bond position
     */
    function claim(uint256 _tokenId) external override nonReentrant {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        BondPosition storage position = _positions[_tokenId];
        require(!position.isStaked, "Position is staked");

        uint256 claimable = _claimableAmount(_tokenId);
        require(claimable > 0, "Nothing to claim");

        position.claimedAmount += claimable;
        position.lastClaimTime = block.timestamp;

        dre.transfer(msg.sender, claimable);

        emit Claimed(_tokenId, claimable);
    }

    /**
     * @notice stake tokens from a bond position
     * @param _tokenId ID of the bond position
     * @param _declaredValue declared value for harberger tax
     */
    function stake(uint256 _tokenId, uint256 _declaredValue) external override nonReentrant {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        BondPosition storage position = _positions[_tokenId];
        require(!position.isStaked, "Already staked");

        uint256 claimable = position.amount - position.claimedAmount;
        require(claimable > 0, "Nothing to stake");

        position.isStaked = true;
        position.claimedAmount += claimable;

        // Approve and stake tokens with 30 day minimum lock
        dre.approve(address(staking), claimable);
        staking.createPosition(msg.sender, claimable, _declaredValue, block.timestamp + STAKING_LOCK_PERIOD);

        emit Staked(_tokenId, claimable);
    }

    /* ======== VIEW FUNCTIONS ======== */

    /**
     * @notice calculate current price of bond
     * @param _id ID of the bond
     * @return current price in quote token
     */
    function _currentPrice(uint256 _id) internal view returns (uint256) {
        Bond memory bond = _bonds[_id];
        if (block.timestamp >= bond.endTime) return bond.finalPrice;

        uint256 timeElapsed = block.timestamp - bond.startTime;
        uint256 duration = bond.endTime - bond.startTime;

        return bond.initialPrice - ((bond.initialPrice - bond.finalPrice) * timeElapsed) / duration;
    }

    /**
     * @notice calculate claimable amount for a position
     * @param _tokenId ID of the bond position
     * @return amount of tokens claimable
     */
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

    function disable(uint256 _id) external onlyPolicy {
        _bonds[_id].enabled = false;
        emit DisableBond(_id);
    }

    /**
     * @notice check if a bond is still active
     * @param _id ID of the bond
     * @return true if bond is active
     */
    function isLive(uint256 _id) external view override returns (bool) {
        Bond memory bond = _bonds[_id];
        return block.timestamp < bond.endTime && bond.capacity > 0;
    }

    /**
     * @notice get current price of a bond
     * @param _id ID of the bond
     * @return current price in quote token
     */
    function currentPrice(uint256 _id) external view override returns (uint256) {
        return _currentPrice(_id);
    }

    /**
     * @notice get claimable amount for a position
     * @param _tokenId ID of the bond position
     * @return amount of tokens claimable
     */
    function claimableAmount(uint256 _tokenId) external view override returns (uint256) {
        return _claimableAmount(_tokenId);
    }

    /**
     * @notice get a bond
     * @param _id ID of the bond
     * @return bond
     */
    function getBond(uint256 _id) external view override returns (Bond memory) {
        return _bonds[_id];
    }

    /**
     * @notice get the number of bonds
     * @return number of bonds
     */
    function bondLength() external view override returns (uint256) {
        return _bonds.length;
    }
}
