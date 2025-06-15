// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../core/AppAccessControlled.sol";
import "../interfaces/IAppStaking.sol";
import "../interfaces/IStaking4626.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @title Staking4626
/// @notice ERC-4626 compliant staking vault that automatically compounds rewards
contract Staking4626 is IStaking4626, ERC20Upgradeable, ReentrancyGuard, AppAccessControlled, IERC721Receiver {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IAppStaking public staking;
    uint256 public tokenId;
    IERC20 public appToken;

    /// @dev Percentage (in basis points) above the deposit amount used as the buy-out (declared) value.
    /// 10% = 1,000 bps.
    uint256 public buyoutPremiumBps;
    uint256 private initialAmount;

    function initialize(string memory name, string memory symbol, address _staking, address _authority)
        external
        initializer
    {
        staking = IAppStaking(_staking);

        __ERC20_init(name, symbol);
        __AppAccessControlled_init(_authority);
        appToken = IERC20(staking.appToken());
        appToken.approve(address(staking), type(uint256).max);

        buyoutPremiumBps = 3_000; // 30%
    }

    /// @inheritdoc IStaking4626
    function setBuyoutPremiumBps(uint256 _buyoutPremiumBps) external onlyGovernor {
        buyoutPremiumBps = _buyoutPremiumBps;
        emit BuyoutPremiumBpsUpdated(buyoutPremiumBps);
    }

    /// @inheritdoc IStaking4626
    function initializePosition(uint256 amount) external {
        require(initialAmount == 0, "Position already initialized");
        initialAmount = _netStakeAfterTax(amount);
        appToken.safeTransferFrom(msg.sender, address(this), amount);
        _increaseAmount(amount);
    }

    /// @inheritdoc IStaking4626
    function harvest() external {
        _harvest();
    }

    /// @inheritdoc IStaking4626
    function recreatePosition() external {
        require(tokenId != 0, "Position not initialized");
        require(initialAmount > 0, "Position not initialized");

        require(staking.ownerOf(tokenId) != address(this), "Already owner"); // Position was sold

        uint256 balance = appToken.balanceOf(address(this));
        require(balance > 0, "No assets to recreate position");
        (tokenId,) = staking.createPosition(address(this), balance, _declaredValue(balance), 0);
    }

    /// -----------------------------------------------------------------------
    /// IERC4626 actions (custom implementation)
    /// -----------------------------------------------------------------------

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256 shares) {
        require(assets > 0, "ZERO_ASSETS");
        shares = previewDeposit(assets);
        require(shares > 0, "ZERO_SHARES");

        _deposit(assets, shares, receiver);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256 assets) {
        require(shares > 0, "ZERO_SHARES");
        assets = previewMint(shares);
        require(assets > 0, "ZERO_ASSETS");

        _deposit(assets, shares, receiver);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        require(assets > 0, "ZERO_ASSETS");
        shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _withdraw(assets, shares, receiver, owner);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        require(shares > 0, "ZERO_SHARES");
        assets = previewRedeem(shares);

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _withdraw(assets, shares, receiver, owner);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view override returns (uint256 totalManagedAssets) {
        require(tokenId != 0, "No position");
        require(staking.ownerOf(tokenId) == address(this), "Not owner");
        IAppStaking.Position memory position = staking.positions(tokenId);
        totalManagedAssets = position.amount + staking.earned(tokenId) - initialAmount;
    }

    // -----------------------------------------------------------------------
    // ERC-4626 preview overrides to account for Harberger tax on *incoming* deposits/mints.
    // -----------------------------------------------------------------------

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        uint256 netAssets = _netStakeAfterTax(assets);
        if (totalSupply() == 0) {
            // First external deposit: 1:1 mapping (post-tax) so that the initial price is 1 share per net RZR.
            return netAssets;
        }
        return _convertToShares(netAssets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) public view override returns (uint256) {
        uint256 netAssets;
        if (totalSupply() == 0) {
            // With no existing shares the initial price is 1:1 (post-tax) – requested shares == desired net assets.
            netAssets = shares;
        } else {
            // Determine the net assets that need to be added to back the requested shares given current price.
            netAssets = _convertToAssets(shares, Math.Rounding.Ceil);
        }

        // Compute the gross amount of assets that must be supplied so that `netAssets` remain after tax.
        return _grossAssetsFromNet(netAssets);
    }

    /// @dev Returns the value of the position in the vault
    /// @return value The value of the position in the vault
    function positionValue() public view returns (uint256 value) {
        value = _positionValue() + initialAmount;
    }

    /// -----------------------------------------------------------------------
    /// Internal helpers
    /// -----------------------------------------------------------------------

    /// @dev Withdraw assets from the position
    /// @param assets The amount of assets to withdraw
    /// @param shares The amount of shares to burn
    /// @param receiver The address to send the assets to
    /// @param owner The address of the owner of the shares
    function _withdraw(uint256 assets, uint256 shares, address receiver, address owner) internal {
        _burn(owner, shares);

        IAppStaking.Position memory position = staking.positions(tokenId);
        uint256 percentage = assets * 1e18 / position.amount;

        staking.splitPosition(tokenId, percentage, receiver);

        // invariant; keep at least one share in the vault forever
        require(totalSupply() > 1e18, "Cannot redeem when there are no shares");

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @dev Deposit assets into the position
    /// @param assets The amount of assets to deposit
    /// @param shares The amount of shares to mint
    /// @param receiver The address to mint the shares to
    function _deposit(uint256 assets, uint256 shares, address receiver) internal {
        appToken.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);

        uint256 posValue = _increaseAmount(assets);
        uint256 amountAfterTax = _netStakeAfterTax(assets);
        require(posValue == amountAfterTax, "Position value mismatch");

        _harvest();
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @dev Harvest rewards and compound them into the position
    function _harvest() internal {
        uint256 balance = appToken.balanceOf(address(this));
        uint256 rewards = staking.claimRewards(tokenId);
        _increaseAmount(rewards + balance);

        emit RewardsCompounded(rewards);
    }

    /// @dev Increase the amount of the position by `amount`
    function _increaseAmount(uint256 amount) internal returns (uint256 val) {
        if (amount == 0) return 0;

        // Use the new 10% premium for the declared value
        uint256 declaredValue = _declaredValue(amount);
        uint256 taxPaid;
        if (tokenId == 0 || staking.ownerOf(tokenId) != address(this)) {
            (tokenId, taxPaid) = staking.createPosition(address(this), amount, declaredValue, 0);
        } else {
            taxPaid = staking.increaseAmount(tokenId, amount, declaredValue);
        }

        val = amount - taxPaid;

        emit Staked(amount);
    }

    /// @dev Given a desired net stake (`netAssets`), returns the gross amount of tokens that must be supplied
    /// to the vault such that, after paying Harberger tax, exactly `netAssets` remain staked.
    function _grossAssetsFromNet(uint256 netAssets) internal view returns (uint256) {
        // factorDenominator = 1e8 (since we multiply two basis-points values of 1e4 each)
        uint256 factorDenominator = 1e8;
        uint256 taxRateBps = staking.harbergerTaxRate(); // out of 1e4
        uint256 subFactor = (10_000 + buyoutPremiumBps) * taxRateBps; // still in 1e8 scale

        // Prevent division by zero if subFactor >= 1e8 (not expected given current params)
        require(subFactor < factorDenominator, "Invalid tax parameters");

        uint256 factorNumerator = factorDenominator - subFactor; // scaled 1e8

        // gross = ceil(net * denom / numerator)
        return Math.mulDiv(netAssets, factorDenominator, factorNumerator, Math.Rounding.Ceil);
    }

    /// @dev Returns the net amount of assets that will remain staked after the harberger tax is paid.
    /// This mirrors the logic in `AppStaking.createPosition` and `increaseAmount`.
    function _netStakeAfterTax(uint256 assets) internal view returns (uint256) {
        // Calculate the buy-out (declared) value first
        uint256 declaredValue = _declaredValue(assets);

        // Determine tax using the staking contract parameters (in basis points)
        uint256 tax = declaredValue * staking.harbergerTaxRate() / 10000;

        // Net assets that actually increase the position amount
        return assets - tax;
    }

    /// @dev Computes the declared value given an `amount` of RZR being staked.
    function _declaredValue(uint256 amount) internal view returns (uint256) {
        // declaredValue = amount * (1 + premium)
        return amount * (10_000 + buyoutPremiumBps) / 10_000;
    }

    function _positionValue() internal view returns (uint256) {
        return staking.earned(tokenId);
    }

    // -----------------------------------------------------------------------
    // IERC4626 getters/converters
    // -----------------------------------------------------------------------

    /// @inheritdoc IERC4626
    function asset() public view override returns (address) {
        return address(staking.appToken());
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) public view override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function maxMint(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) public view override returns (uint256) {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) public view override returns (uint256) {
        return balanceOf(owner);
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    // -----------------------------------------------------------------------
    // Internal conversion helpers (replicating OZ math)
    // -----------------------------------------------------------------------

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view returns (uint256) {
        if (totalSupply() == 0) {
            return assets; // 1:1 after tax already handled by caller when supply = 0
        }
        return assets.mulDiv(totalSupply(), totalAssets() + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view returns (uint256) {
        if (totalSupply() == 0) {
            return shares;
        }
        return shares.mulDiv(totalAssets() + 1, totalSupply(), rounding);
    }

    // -----------------------------------------------------------------------
    // ERC721 hook – accept staking position NFTs
    // -----------------------------------------------------------------------

    /// @notice Handles the receipt of an AppStaking position NFT. Users can transfer their position
    ///         directly to this vault and receive shares in exchange. The vault makes sure the
    ///         position is using at least the required buy-out (declared) value and, if not,
    ///         pulls the required RZR from the sender to pay the additional Harberger tax.
    /// @dev Only NFTs from the configured `staking` contract are accepted.
    /// @param operator The address which called `safeTransferFrom` (should be the user)
    /// @param from     The previous owner of the NFT (the user)
    /// @param _tokenId The ID of the staking position NFT being transferred
    /// @return The selector to confirm the NFT transfer
    function onERC721Received(address operator, address from, uint256 _tokenId, bytes calldata)
        external
        override
        returns (bytes4)
    {
        // Only accept NFTs coming from the official staking contract
        require(msg.sender == address(staking), "Unsupported NFT sender");

        require(false, "feature in beta");

        // Fetch position details
        IAppStaking.Position memory pos = staking.positions(_tokenId);

        // Ensure the declared value meets the vault's buy-out premium requirement.
        uint256 requiredDeclaredValue = _declaredValue(pos.amount);
        if (pos.declaredValue < requiredDeclaredValue) {
            uint256 additionalDeclaredValue = requiredDeclaredValue - pos.declaredValue;

            // Compute the tax that must be paid for the additional declared value
            uint256 taxRateBps = staking.harbergerTaxRate();
            uint256 taxDue = additionalDeclaredValue * taxRateBps / 10_000;

            // Pull the tax from the user (must have approved the vault beforehand)
            appToken.safeTransferFrom(from, address(this), taxDue);

            // Forward the tax to the staking contract where it will be burned via `_distributeTax`
            appToken.safeTransfer(address(staking), taxDue);

            // Approve in case it's needed (safety for non-infinite approvals)
            appToken.approve(address(staking), taxDue);

            // Increase the declared value and pay the tax
            staking.increaseDeclaredValue(_tokenId, additionalDeclaredValue);
        }

        uint256 sharesToMint;

        require(tokenId != 0 && staking.ownerOf(tokenId) == address(this), "Already owner");

        // Existing vault position present – merge the new NFT into it.
        uint256 prevAmount = staking.positions(tokenId).amount;

        // This call burns `_tokenId` and adds its amount to `tokenId`.
        staking.mergePositions(tokenId, _tokenId);

        uint256 newAmount = staking.positions(tokenId).amount;
        uint256 addedAssets = newAmount - prevAmount;

        // Mint shares proportionally to the added assets
        sharesToMint = _convertToShares(addedAssets, Math.Rounding.Floor);

        // Emit event with only the added assets portion
        emit Deposit(operator, from, addedAssets, sharesToMint);

        require(sharesToMint > 0, "ZERO_SHARES");
        _mint(from, sharesToMint);

        return this.onERC721Received.selector;
    }
}
