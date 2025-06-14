// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IOracle.sol";
import "../interfaces/IAggregatorV3.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AaveAdapterOracle is IOracle {
    IAggregatorV3 public immutable AGGREGATOR;
    uint256 private decimalsToAdjust;

    constructor(IAggregatorV3 _aggregator) {
        AGGREGATOR = _aggregator;
        uint8 decimals = AGGREGATOR.decimals();
        decimalsToAdjust = 10 ** (18 - decimals);
    }

    function getPrice() external view override returns (uint256) {
        int256 answer = AGGREGATOR.latestAnswer();
        return uint256(answer) * decimalsToAdjust;
    }
}
