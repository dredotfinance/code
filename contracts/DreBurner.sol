// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./DreAccessControlled.sol";
import "./interfaces/IDreOracle.sol";
import "./interfaces/IDRE.sol";

import "forge-std/console.sol";

/// @title DreBurner
/// @notice Contract responsible for burning DRE tokens and updating the floor price
/// @dev Implements a mechanism to burn DRE tokens and adjust the floor price based on the burn amount
contract DreBurner is DreAccessControlled {
    uint256 private immutable ONE = 1e18; // 100 %
    IDreOracle public dreOracle;
    IDRE public dre;

    /// @notice Emitted when tokens are burned and floor price is updated
    /// @param amount The amount of tokens burned
    /// @param newFloorPrice The new floor price after the burn
    event Burned(uint256 amount, uint256 newFloorPrice);

    /// @notice Initializes the DreBurner contract
    /// @param _dreOracle Address of the DRE oracle contract
    /// @param _dre Address of the DRE token contract
    /// @param _authority Address of the authority contract
    function initialize(address _dreOracle, address _dre, address _authority) external reinitializer(1) {
        __DreAccessControlled_init(_authority);
        dreOracle = IDreOracle(_dreOracle);
        dre = IDRE(_dre);
        dre.approve(address(this), type(uint256).max);
    }

    /// @notice Burns DRE tokens and updates the floor price
    /// @dev Only callable by executors. Burns all DRE tokens held by this contract
    /// and updates the floor price based on the burn amount. The new floor price
    /// must be greater than the current price but less than 2x the current price.
    function burn() external onlyExecutor {
        uint256 balance = dre.balanceOf(address(this));
        uint256 floorPrice = dreOracle.getDrePrice();
        uint256 totalSupply = dre.totalSupply();
        uint256 newFloorPrice = calculateFloorUpdate(balance, totalSupply, floorPrice);

        require(newFloorPrice >= floorPrice, "New floor price must be greater than current floor price");
        require(newFloorPrice <= floorPrice * 2, "New floor price must be less than 2x current floor price");

        dre.burn(balance);
        dreOracle.setDrePrice(newFloorPrice);
        emit Burned(balance, newFloorPrice);
    }

    /// @notice Calculates the new floor price based on the burn amount
    /// @param amountToBurn The amount of tokens to burn
    /// @param totalSupply The total supply of DRE tokens
    /// @param floorPrice The current floor price
    /// @return newFloorPrice The calculated new floor price
    /// @dev Uses an exponential formula to calculate the price multiplier:
    /// - For 90% burn: 1 / (1 - 0.9) = 10x
    /// - For 50% burn: 1 / (1 - 0.5) = 2x
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
    /// @param token Address of the token to recover
    /// @param amount Amount of tokens to recover
    /// @dev Only callable by governors. Transfers tokens to the operations treasury
    function recoverERC20(address token, uint256 amount) external onlyGovernor {
        IERC20(token).transfer(authority.operationsTreasury(), amount);
    }
}
