// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AverageCappedOracle
 * @notice This contract takes the average of two oracle prices and reverts if they deviate too much
 * @dev Uses a percentage-based deviation check to ensure oracle reliability
 */
contract AverageCappedOracle is IOracle {
    IOracle public oracle0;
    IOracle public oracle1;
    uint256 public maxDeviationPercent; // In basis points (1% = 100)

    event MaxDeviationUpdated(uint256 newMaxDeviation);

    error ExcessiveDeviation(uint256 price0, uint256 price1, uint256 deviation);

    /**
     * @notice Constructor
     * @param _oracle0 First oracle
     * @param _oracle1 Second oracle
     * @param _maxDeviationPercent Maximum allowed deviation in basis points (1% = 100)
     */
    constructor(IOracle _oracle0, IOracle _oracle1, uint256 _maxDeviationPercent) {
        require(address(_oracle0) != address(0), "Invalid oracle0 address");
        require(address(_oracle1) != address(0), "Invalid oracle1 address");
        require(_maxDeviationPercent > 0 && _maxDeviationPercent <= 1000, "Invalid max deviation"); // Max 10%

        oracle0 = _oracle0;
        oracle1 = _oracle1;
        maxDeviationPercent = _maxDeviationPercent;
    }

    /**
     * @notice Calculates the average price from both oracles
     * @return The average price
     */
    function getPrice() external override returns (uint256) {
        uint256 price0 = oracle0.getPrice();
        uint256 price1 = oracle1.getPrice();

        // Calculate deviation as a percentage
        uint256 deviation;
        if (price0 > price1) {
            deviation = ((price0 - price1) * 10000) / price1; // Convert to basis points
        } else {
            deviation = ((price1 - price0) * 10000) / price0; // Convert to basis points
        }

        // Check if deviation exceeds maximum allowed
        if (deviation > maxDeviationPercent) {
            revert ExcessiveDeviation(price0, price1, deviation);
        }

        // Return average price
        return (price0 + price1) / 2;
    }
}
