// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BeaconOracle
 * @notice This contract is a wrapper around an IOracle that allows for the beacon to be updated.
 */
contract BeaconOracle is IOracle, Ownable {
    IOracle public beacon;

    event BeaconUpdated(IOracle indexed newBeacon);

    constructor(IOracle _beacon) Ownable(msg.sender) {
        beacon = _beacon;
        emit BeaconUpdated(_beacon);
    }

    function setBeacon(IOracle _beacon) external onlyOwner {
        beacon = _beacon;
        emit BeaconUpdated(_beacon);
    }

    function getPrice() external view override returns (uint256) {
        return beacon.getPrice();
    }
}
