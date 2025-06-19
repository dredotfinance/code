// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CappedOracle
 * @notice This contract takes an oracle and reverts if the price is outside of a certain range
 * @dev Uses a percentage-based deviation check to ensure oracle reliability
 */
contract CappedOracle is IOracle {
    IOracle public oracle;
    uint256 public maxUpperBound;
    uint256 public maxLowerBound;

    /**
     * @notice Constructor
     * @param _oracle Oracle
     * @param _maxUpperBound Maximum allowed upper bound
     * @param _maxLowerBound Maximum allowed lower bound
     */
    constructor(IOracle _oracle, uint256 _maxUpperBound, uint256 _maxLowerBound) {
        require(address(_oracle) != address(0), "Invalid oracle address");
        require(_maxUpperBound > 0, "Invalid max upper bound");
        require(_maxLowerBound > 0, "Invalid max lower bound");

        oracle = _oracle;
        maxUpperBound = _maxUpperBound;
        maxLowerBound = _maxLowerBound;
    }

    /**
     * @notice Calculates the average price from both oracles
     * @return The average price
     */
    function getPrice() external view override returns (uint256) {
        uint256 price = oracle.getPrice();

        // Calculate deviation as a percentage
        require(price <= maxUpperBound, "Price exceeds upper bound");
        require(price >= maxLowerBound, "Price exceeds lower bound");

        return price;
    }
}
