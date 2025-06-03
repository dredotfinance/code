// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IAggregatorV3.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IOracle.sol";

/**
 * @notice This contract is a wrapper around an AggregatorV3Interface that allows for the price to be scaled.
 * @dev The price is scaled to 1e18.
 * @dev The oracle is the AggregatorV3Interface that provides the price.
 * @dev The scale is the factor by which the price is scaled.
 */
contract ScaledAggregatorOracleE18 is IOracle {
    AggregatorV3Interface public oracle;
    int256 public scale;

    constructor(AggregatorV3Interface _oracle) {
        oracle = _oracle;
        scale = int256(10 ** (18 - oracle.decimals()));
    }

    function getPrice() external view returns (uint256) {
        return uint256(oracle.latestAnswer() * scale);
    }
}
