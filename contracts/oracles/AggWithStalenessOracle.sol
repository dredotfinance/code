// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IOracle.sol";
import "../interfaces/IAggregatorV3.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AggWithStalenessOracle
 * @notice This contract is a wrapper around an IAggregatorV3 that ports it in the IOracle interface.
 */
contract AggWithStalenessOracle is IOracle {
    IAggregatorV3 public immutable AGGREGATOR;
    uint256 public immutable MAX_STALENESS;
    uint256 private decimalsToAdjust;

    constructor(IAggregatorV3 _aggregator, uint256 _maxStaleness) {
        AGGREGATOR = _aggregator;
        MAX_STALENESS = _maxStaleness;
        uint8 decimals = AGGREGATOR.decimals();
        decimalsToAdjust = 10 ** (18 - decimals);
    }

    function getPrice() external view override returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = AGGREGATOR
            .latestRoundData();
        require(updatedAt > block.timestamp - MAX_STALENESS, "Stale price");
        return uint256(answer) * decimalsToAdjust;
    }
}
