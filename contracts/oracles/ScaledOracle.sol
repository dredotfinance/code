// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IAggregatorV3.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ScaledOracle
 * @notice This contract is a wrapper around an AggregatorV3Interface that allows for the price to be scaled.
 */
contract ScaledOracle is AggregatorV3Interface, Ownable {
    AggregatorV3Interface public oracle;
    int256 public scale;

    constructor(AggregatorV3Interface _oracle) Ownable(msg.sender) {
        oracle = _oracle;
        scale = int256(10 ** (18 - oracle.decimals()));
    }

    function decimals() external view override returns (uint8) {
        return 18;
    }

    function description() external view override returns (string memory) {
        return oracle.description();
    }

    function version() external view override returns (uint256) {
        return oracle.version();
    }

    function getRoundData(uint80 _roundId_)
        external
        view
        override
        returns (uint80  , int256  , uint256  , uint256  , uint80  )
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = oracle.getRoundData(_roundId_);
        return (roundId, answer * scale, startedAt, updatedAt, answeredInRound);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = oracle.latestRoundData();
        return (roundId, answer * scale, startedAt, updatedAt, answeredInRound);
    }

    function latestAnswer() external view override returns (int256) {
        return oracle.latestAnswer() * scale;
    }
}
