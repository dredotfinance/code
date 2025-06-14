// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../AppAccessControlled.sol";
import "../interfaces/IAppStaking.sol";

/// @title Staking4626
/// @notice ERC-4626 compliant staking vault that automatically compounds rewards
contract Staking4626 is ERC4626Upgradeable, ReentrancyGuard, AppAccessControlled {
    using SafeERC20 for IERC20;

    IAppStaking public staking;
    uint256 public tokenId;

    event RewardsCompounded(uint256 amount);
    event CompoundIntervalUpdated(uint256 oldInterval, uint256 newInterval);

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

    function initializePosition(uint256 amount) external {
        _increaseAmount(amount);
    }

    function harvest() external {
        _harvest();
    }

    function _harvest() internal {
        uint256 rewards = staking.claimRewards(tokenId);
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        _increaseAmount(rewards + balance);
    }

    function _increaseAmount(uint256 amount) internal {
        uint256 declaredValue = amount * 105 / 100;
        if (tokenId == 0 || staking.ownerOf(tokenId) != address(this)) {
            (tokenId,) = staking.createPosition(address(this), amount, declaredValue, 0);
        } else {
            staking.increaseAmount(tokenId, amount, declaredValue);
        }
    }

    /// @notice Deposits assets into the vault and stakes them
    /// @param assets Amount of assets to deposit
    /// @param receiver Address to receive the shares
    /// @return shares Amount of shares minted
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        // First deposit the assets into the vault
        shares = super.deposit(assets, receiver);

        // Then stake the assets
        _increaseAmount(assets);
    }

    /// @notice Mints shares and stakes the underlying assets
    /// @param shares Amount of shares to mint
    /// @param receiver Address to receive the shares
    /// @return assets Amount of assets staked
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        // First mint the shares
        assets = super.mint(shares, receiver);

        // Then stake the assets
        IERC20(asset()).approve(address(staking), assets);
        staking.createPosition(address(this), assets, assets, 0);
    }

    /// @notice Withdraws assets from the vault and unstakes them
    /// @param assets Amount of assets to withdraw
    /// @param receiver Address to receive the assets
    /// @param owner Address that owns the shares
    /// @return shares Amount of shares burned
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        uint256 percentage = assets * 1e18 / totalAssets();

        // withdraw the assets from staking
        _harvest();
        staking.splitPosition(tokenId, percentage, receiver);

        // Withdraw from the vault
        shares = super.withdraw(assets, receiver, owner);
    }

    /// @notice Redeems shares and unstakes the underlying assets
    /// @param shares Amount of shares to redeem
    /// @param receiver Address to receive the assets
    /// @param owner Address that owns the shares
    /// @return assets Amount of assets withdrawn
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

    /// @notice Returns the total amount of assets in the vault
    /// @return totalManagedAssets Total assets including staked amount and pending rewards
    function totalAssets() public view override returns (uint256 totalManagedAssets) {
        require(tokenId != 0, "No position");
        require(staking.ownerOf(tokenId) == address(this), "Not owner");
        IAppStaking.Position memory position = staking.positions(tokenId);
        totalManagedAssets = position.amount + staking.earned(tokenId);
    }
}
