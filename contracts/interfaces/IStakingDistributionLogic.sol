// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IStakingDistributionLogic {
    function allocate(uint256 yield, uint256 totalSupply, uint256 stakedSupply, uint256 floorPrice)
        external
        pure
        returns (uint256 toStakers, uint256 toOps, uint256 newFloorPrice);
}
