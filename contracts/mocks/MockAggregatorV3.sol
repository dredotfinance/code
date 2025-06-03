// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IAggregatorV3.sol";

contract MockAggregatorV3 is AggregatorV3Interface {
    uint8 private _decimals;
    int256 private _price;

    constructor(uint8 decimals_, int256 price_) {
        _decimals = decimals_;
        _price = price_;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "Mock AggregatorV3";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, block.timestamp, block.timestamp, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, _price, block.timestamp, block.timestamp, 1);
    }

    function latestAnswer() external view override returns (int256) {
        return _price;
    }

    function setPrice(int256 price_) external {
        _price = price_;
    }

    function setDecimals(uint8 decimals_) external {
        _decimals = decimals_;
    }
}
