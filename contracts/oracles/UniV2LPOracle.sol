// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IAggregatorV3.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UniV2LPOracle
 * @notice This contract is a wrapper around an AggregatorV3Interface that allows for the beacon to be updated.
 */
contract UniV2LPOracle is AggregatorV3Interface {
    address public uniV2LP;
    AggregatorV3Interface public token0Oracle;
    AggregatorV3Interface public token1Oracle;

    constructor(address _uniV2LP, AggregatorV3Interface _token0Oracle, AggregatorV3Interface _token1Oracle)  {
        uniV2LP = _uniV2LP;
        token0Oracle = _token0Oracle;
        token1Oracle = _token1Oracle;
    }

    function decimals() external view override returns (uint8) {
        return 18;
    }

    function description() external view override returns (string memory) {
        return "UniV2LPOracle";
    }

    function version() external view override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId_)
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
        return (0, getPrice(), block.timestamp, block.timestamp, 0);
    }

    function latestAnswer() external view override returns (int256) {

        return getPrice();
    }

    function getPrice() public view returns (int256) {
        // (int256 token0Price, int256 token1Price) = (token0Oracle.latestAnswer(), token1Oracle.latestAnswer());
        // uint256 token0Decimals = token0Oracle.decimals();
        // uint256 token1Decimals = token1Oracle.decimals();
        // uint256 token0Amount = 10 ** token0Decimals;
        // uint256 token1Amount = 10 ** token1Decimals;
        // uint256 price = token0Price * token1Amount / token1Price;

        return 1e18;
    }
}
