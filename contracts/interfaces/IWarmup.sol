// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

interface IWarmup {
    function retrieve(address staker_, uint256 amount_) external;
}
