// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./AppAccessControlled.sol";
import "../interfaces/IAppOracle.sol";
import "../interfaces/IApp.sol";

/// @title AppBurner
/// @notice This contract is used to burn the balance of the App contract
contract AppBurner is AppAccessControlled {
    /* ========== STATE VARIABLES ========== */

    uint256 private immutable ONE = 1e18; // 100 %
    IAppOracle public appOracle;
    IApp public app;

    /* ========== EVENTS ========== */
    event Burned(uint256 amount, uint256 newFloorPrice);

    /// @notice Initializes the AppBurner contract
    /// @dev This function is only callable once
    /// @param _appOracle The address of the appOracle contract
    /// @param _dre The address of the dre contract
    /// @param _authority The address of the authority contract
    function initialize(address _appOracle, address _dre, address _authority) external initializer {
        __AppAccessControlled_init(_authority);
        appOracle = IAppOracle(_appOracle);
        app = IApp(_dre);
        app.approve(address(this), type(uint256).max);
    }

    /// @notice Burns the balance of the App contract
    /// @dev This function is only callable by the executor
    function burn() external onlyExecutor {
        uint256 balance = app.balanceOf(address(this));
        uint256 floorPrice = appOracle.getTokenPrice();
        uint256 totalSupply = app.totalSupply();
        uint256 newFloorPrice = calculateFloorUpdate(balance, totalSupply, floorPrice);

        require(newFloorPrice >= floorPrice, "New floor price must be greater than current floor price");
        require(newFloorPrice <= floorPrice * 2, "New floor price must be less than 2x current floor price");

        app.burn(balance);
        appOracle.setTokenPrice(newFloorPrice);
        emit Burned(balance, newFloorPrice);
    }

    /// @notice Calculates the new floor price based on the amount to burn and the total supply
    /// @param amountToBurn The amount of tokens to burn
    /// @param totalSupply The total supply of the App contract
    /// @param floorPrice The current floor price
    /// @return newFloorPrice The new floor price
    function calculateFloorUpdate(uint256 amountToBurn, uint256 totalSupply, uint256 floorPrice)
        public
        pure
        returns (uint256 newFloorPrice)
    {
        if (amountToBurn == 0 || floorPrice == 0 || totalSupply == 0) return floorPrice;

        // Calculate burn percentage (in basis points)
        uint256 burnPercentage = (amountToBurn * 10000) / totalSupply;

        require(burnPercentage < 10000, "Burn percentage cannot be greater than 100%");

        // Calculate price multiplier using exponential formula
        // For 90% burn: 1 / (1 - 0.9) = 1 / 0.1 = 10x
        // For 50% burn: 1 / (1 - 0.5) = 1 / 0.5 = 2x
        uint256 priceMultiplier = (ONE * 10000) / (10000 - burnPercentage);

        // Apply the multiplier to get new floor price
        newFloorPrice = (floorPrice * priceMultiplier) / ONE;
    }

    /// @notice Recovers ERC20 tokens from the contract
    /// @dev This function is only callable by the governor
    /// @param token The address of the token to recover
    /// @param amount The amount of tokens to recover
    function recoverERC20(address token, uint256 amount) external onlyGovernor {
        IERC20(token).transfer(authority.operationsTreasury(), amount);
    }
}
