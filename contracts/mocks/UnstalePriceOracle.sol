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

    function getRoundData(uint80 _roundId_)
        external
        view
        override
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        (_roundId, _answer, _startedAt, _updatedAt, _answeredInRound) = oracle.getRoundData(_roundId_);
        return (_roundId, _answer * decimalsToAdd, _startedAt, _updatedAt, _answeredInRound);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        (_roundId, _answer, _startedAt, _updatedAt, _answeredInRound) = oracle.latestRoundData();
        return (_roundId, _answer * decimalsToAdd, _startedAt, block.timestamp, _answeredInRound);
    }

    function latestAnswer() external view override returns (int256) {
        return oracle.latestAnswer() * decimalsToAdd;
    }
}
