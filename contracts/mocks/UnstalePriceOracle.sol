// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IAggregatorV3.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UnstalePriceOracle is AggregatorV3Interface, Ownable {
    AggregatorV3Interface public oracle;
    int256 public decimalsToAdd;
    uint8 public decimals;

    constructor(AggregatorV3Interface _oracle, uint8 _decimals) Ownable(msg.sender) {
        oracle = _oracle;
        uint8 oracleDecimals = oracle.decimals();
        decimalsToAdd = int256(10 ** (18 - oracleDecimals));
        decimals = _decimals;
    }

    function description() external view override returns (string memory) {
        return oracle.description();
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = oracle.getRoundData(_roundId);
        return (roundId, answer * decimalsToAdd, startedAt, updatedAt, answeredInRound);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = oracle.latestRoundData();
        return (roundId, answer * decimalsToAdd, startedAt, block.timestamp, answeredInRound);
    }

    function latestAnswer() external view override returns (int256) {
        return oracle.latestAnswer() * decimalsToAdd;
    }
}
