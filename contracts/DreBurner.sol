// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./DreAccessControlled.sol";
import "./interfaces/IDreOracle.sol";
import "./interfaces/IDRE.sol";

contract DreBurner is DreAccessControlled {
    uint256 private constant ONE = 1e18; // 100 %
    IDreOracle public dreOracle;
    IDRE public dre;

    function initialize(address _dreOracle, address _dre, address _authority) external reinitializer(1) {
        __DreAccessControlled_init(_authority);
        dreOracle = IDreOracle(_dreOracle);
        dre = IDRE(_dre);
        dre.approve(address(this), type(uint256).max);
    }

    function burn() external onlyExecutor {
        uint256 balance = dre.balanceOf(address(this));
        uint256 floorPrice = dreOracle.getDrePrice();
        uint256 totalSupply = dre.totalSupply();
        uint256 newFloorPrice = calculateFloorUpdate(balance, totalSupply, floorPrice);
        dreOracle.setDrePrice(newFloorPrice);
    }

    function calculateFloorUpdate(uint256 amountToBurn, uint256 totalSupply, uint256 floorPrice)
        public
        pure
        returns (uint256 newFloorPrice)
    {
        if (amountToBurn == 0 || floorPrice == 0 || totalSupply == 0) return floorPrice;

        // Calculate burn percentage (in basis points)
        uint256 burnPercentage = (amountToBurn * 10000) / totalSupply;

        // Calculate price multiplier using exponential formula
        // For 90% burn: 1 / (1 - 0.9) = 1 / 0.1 = 10x
        // For 50% burn: 1 / (1 - 0.5) = 1 / 0.5 = 2x
        uint256 priceMultiplier = (ONE * 10000) / (10000 - burnPercentage);

        // Apply the multiplier to get new floor price
        newFloorPrice = (floorPrice * priceMultiplier) / ONE;
    }
}
