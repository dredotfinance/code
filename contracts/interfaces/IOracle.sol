// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

interface IOracle {
    function getPrice() external view returns (uint256);
}
