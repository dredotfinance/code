// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

interface IYieldLogic {
    function calcEpoch(uint256 pcvUsd, uint256 supply, uint256 floorPrice, uint256 epochsPerYear)
        external
        pure
        returns (uint256 apr, uint256 epochMint);
}
