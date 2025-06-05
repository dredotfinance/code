// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/libraries/StakingDistributionLogic.sol";

contract StakingDistributionLogicTest is Test {
    using StakingDistributionLogic for uint256;

    function setUp() public {}

    function testAllocate_ZeroStakingRatio() public {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 0; // No staked tokens
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) =
            StakingDistributionLogic.allocate(yieldTokens, totalSupply, stakedSupply, floorPrice);

        // With 0% staking ratio:
        // - 15% to floor (minimum)
        // - 10% to ops
        // - 75% to stakers
        assertEq(toOps, 100e18); // 10% of 1000
        assertEq(toStakers, 750e18); // 75% of 1000

        // Floor price increase = 1 * 0.15 * 1000 / 1000 = 0.15
        assertEq(newFloorPrice, 115e16); // 1.15 USD per token
    }

    function testAllocate_FullStakingRatio() public {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 1000e18; // All tokens staked
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) =
            StakingDistributionLogic.allocate(yieldTokens, totalSupply, stakedSupply, floorPrice);

        // With 100% staking ratio:
        // - 50% to floor (maximum)
        // - 10% to ops
        // - 40% to stakers
        assertEq(toOps, 100e18); // 10% of 1000
        assertEq(toStakers, 400e18); // 40% of 1000

        // Floor price increase = 1 * 0.5 * 1000 / 1000 = 0.5
        assertEq(newFloorPrice, 15e17); // 1.5 USD per token
    }

    function testAllocate_HalfStakingRatio() public {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 500e18; // Half tokens staked
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) =
            StakingDistributionLogic.allocate(yieldTokens, totalSupply, stakedSupply, floorPrice);

        // With 50% staking ratio:
        // - 40% to floor (15% + 50% * 0.5)
        // - 10% to ops
        // - 50% to stakers
        assertEq(toOps, 100e18); // 10% of 1000
        assertEq(toStakers, 500e18); // 50% of 1000

        // Floor price increase = 1 * 0.4 * 1000 / 1000 = 0.4
        assertEq(newFloorPrice, 14e17); // 1.4 USD per token
    }

    function testAllocate_ZeroYield() public {
        uint256 yieldTokens = 0; // No yield
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 500e18; // Half tokens staked
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) =
            StakingDistributionLogic.allocate(yieldTokens, totalSupply, stakedSupply, floorPrice);

        // With 0 yield:
        // - 40% to floor (15% + 50% * 0.5)
        // - 10% to ops
        // - 50% to stakers
        assertEq(toOps, 0); // 10% of 0
        assertEq(toStakers, 0); // 50% of 0

        // Floor price increase = 1 * 0.4 * 0 / 1000 = 0
        assertEq(newFloorPrice, floorPrice); // No change in floor price
    }

    function testAllocate_Precision() public {
        uint256 yieldTokens = 1e18; // 1 token
        uint256 totalSupply = 1e18; // 1 total supply
        uint256 stakedSupply = 1e17; // 10% staked
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) =
            StakingDistributionLogic.allocate(yieldTokens, totalSupply, stakedSupply, floorPrice);

        // With 10% staking ratio:
        // - 20% to floor (15% + 50% * 0.1)
        // - 10% to ops
        // - 70% to stakers
        assertEq(toOps, 1e17); // 10% of 1
        assertEq(toStakers, 7e17); // 70% of 1

        // Floor price increase = 1 * 0.2 * 1 / 1 = 0.2
        assertEq(newFloorPrice, 12e17); // 1.2 USD per token
    }

    function testAllocate_ZeroTotalSupply() public {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 0; // No tokens in circulation
        uint256 stakedSupply = 0; // No staked tokens
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) =
            StakingDistributionLogic.allocate(yieldTokens, totalSupply, stakedSupply, floorPrice);

        // With 0 total supply:
        assertEq(toOps, 0);
        assertEq(toStakers, 0);
        assertEq(newFloorPrice, floorPrice);
    }

    function testAllocate_ZeroFloorPrice() public {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 500e18; // Half tokens staked
        uint256 floorPrice = 0; // 0 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) =
            StakingDistributionLogic.allocate(yieldTokens, totalSupply, stakedSupply, floorPrice);

        // With 0 floor price:
        assertEq(toOps, 0);
        assertEq(toStakers, 0);
        assertEq(newFloorPrice, 0);
    }
}
