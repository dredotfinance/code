// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IAggregatorV3.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract DumbAggregatorOracle is AggregatorV3Interface {
    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external
        view
        override
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        return latestRoundData();
    }

    function latestRoundData()
        public
        view
        override
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        return (0, _getPrice(), block.timestamp, block.timestamp, 0);
    }

    function latestAnswer() external view override returns (int256) {
        return _getPrice();
    }

    function _getPrice() internal view virtual returns (int256);
}
