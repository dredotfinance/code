// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IAggregatorV3.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BeaconOracle
 * @notice This contract is a wrapper around an AggregatorV3Interface that allows for the beacon to be updated.
 */
contract BeaconOracle is AggregatorV3Interface, Ownable {
    AggregatorV3Interface public beacon;

    event BeaconUpdated(AggregatorV3Interface indexed newBeacon);

    constructor(AggregatorV3Interface _beacon) Ownable(msg.sender) {
        beacon = _beacon;
        emit BeaconUpdated(_beacon);
    }

    function setBeacon(AggregatorV3Interface _beacon) external onlyOwner {
        beacon = _beacon;
        emit BeaconUpdated(_beacon);
    }

    function decimals() external view override returns (uint8) {
        return beacon.decimals();
    }

    function description() external view override returns (string memory) {
        return beacon.description();
    }

    function version() external view override returns (uint256) {
        return beacon.version();
    }

    function getRoundData(uint80 _roundId_)
        external
        view
        override
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        return beacon.getRoundData(_roundId_);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        return beacon.latestRoundData();
    }

    function latestAnswer() external view override returns (int256) {
        return beacon.latestAnswer();
    }
}
