// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../core/AppAccessControlled.sol";
import "../interfaces/IAppStaking.sol";
import "../interfaces/IStaking4626.sol";

/// @title Staking4626
/// @notice ERC-4626 compliant staking vault that automatically compounds rewards
contract Staking4626 is IStaking4626, ERC4626Upgradeable, ReentrancyGuard, AppAccessControlled {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IAppStaking public staking;
    uint256 public tokenId;

    /// @dev Percentage (in basis points) above the deposit amount used as the buy-out (declared) value.
    /// 10% = 1,000 bps.
    uint256 private constant BUYOUT_PREMIUM_BPS = 1_000; // 10%

    function initialize(string memory name, string memory symbol, address _staking, address _authority)
        external
        initializer
    {
        staking = IAppStaking(_staking);

        __ERC4626_init(staking.appToken());
        __ERC20_init(name, symbol);
        __AppAccessControlled_init(_authority);

        IERC20(asset()).approve(address(staking), type(uint256).max);
    }

    /// @inheritdoc IStaking4626
    function initializePosition(uint256 amount) external {
        _increaseAmount(amount);
    }

    /// @inheritdoc IStaking4626
    function harvest() external {
        _harvest();
    }

    function _harvest() internal {
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        uint256 rewards = staking.claimRewards(tokenId);
        _increaseAmount(rewards + balance);

        emit RewardsCompounded(rewards);
    }

    function _increaseAmount(uint256 amount) internal {
        if (amount == 0) return;
        // Use the new 10% premium for the declared value
        uint256 declaredValue = _declaredValue(amount);
        if (tokenId == 0 || staking.ownerOf(tokenId) != address(this)) {
            (tokenId,) = staking.createPosition(address(this), amount, declaredValue, 0);
        } else {
            staking.increaseAmount(tokenId, amount, declaredValue);
        }

        emit Staked(amount);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        // First deposit the assets into the vault
        shares = super.deposit(assets, receiver);

        // Then stake the assets
        _increaseAmount(assets);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        // First mint the shares
        assets = super.mint(shares, receiver);

        // Then stake the assets
        IERC20(asset()).approve(address(staking), assets);
        staking.createPosition(address(this), assets, assets, 0);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        uint256 percentage = assets * 1e18 / totalAssets();

        // withdraw the assets from staking
        _harvest();
        staking.splitPosition(tokenId, percentage, receiver);

        // Withdraw from the vault
        shares = super.withdraw(assets, receiver, owner);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        // First calculate how many assets we need to withdraw
        assets = previewRedeem(shares);
        uint256 percentage = assets * 1e18 / totalAssets();

        // Then withdraw the assets from staking
        _harvest();
        staking.splitPosition(tokenId, percentage, receiver);

        // Finally redeem the shares
        assets = super.redeem(shares, receiver, owner);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view override returns (uint256 totalManagedAssets) {
        require(tokenId != 0, "No position");
        require(staking.ownerOf(tokenId) == address(this), "Not owner");
        IAppStaking.Position memory position = staking.positions(tokenId);
        totalManagedAssets = position.amount + staking.earned(tokenId);
    }

    // -----------------------------------------------------------------------
    // ERC-4626 preview overrides to account for Harberger tax on *incoming* deposits/mints.
    // -----------------------------------------------------------------------

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        uint256 netAssets = _netStakeAfterTax(assets);
        return _convertToShares(netAssets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) public view override returns (uint256) {
        // Determine the net assets that need to be added to back the requested shares.
        uint256 netAssets = _convertToAssets(shares, Math.Rounding.Ceil);

        // Invert the tax equation to compute the gross amount of assets that must be supplied so that
        // `netAssets` remain after the vault pays Harberger tax.
        uint256 grossAssets = _grossAssetsFromNet(netAssets);
        return grossAssets;
    }

    /// -----------------------------------------------------------------------
    /// Internal helpers
    /// -----------------------------------------------------------------------

    /// @dev Given a desired net stake (`netAssets`), returns the gross amount of tokens that must be supplied
    /// to the vault such that, after paying Harberger tax, exactly `netAssets` remain staked.
    function _grossAssetsFromNet(uint256 netAssets) internal view returns (uint256) {
        // factorDenominator = 1e8 (since we multiply two basis-points values of 1e4 each)
        uint256 factorDenominator = 1e8;
        uint256 taxRateBps = staking.harbergerTaxRate(); // out of 1e4
        uint256 subFactor = (10_000 + BUYOUT_PREMIUM_BPS) * taxRateBps; // still in 1e8 scale

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
    function _declaredValue(uint256 amount) internal pure returns (uint256) {
        // declaredValue = amount * (1 + premium)
        return amount * (10_000 + BUYOUT_PREMIUM_BPS) / 10_000;
    }
}
