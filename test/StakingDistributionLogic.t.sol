// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/libraries/StakingDistributionLogic.sol";

contract StakingDistributionLogicTest is Test {
    using StakingDistributionLogic for uint256;

    // Constants for testing
    uint256 constant OPS_RATIO = 0.1e18; // 10%
    uint256 constant FLOOR_RATIO_MIN = 0.15e18; // 15%
    uint256 constant FLOOR_RATIO_MAX = 0.5e18; // 50%
    uint256 constant FLOOR_RATIO_SLOPE = 0.5e18; // 50%

    function setUp() public {}

    function testAllocate_ZeroStakingRatio() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 0; // No staked tokens
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            floorPrice,
            OPS_RATIO,
            FLOOR_RATIO_MIN,
            FLOOR_RATIO_MAX,
            FLOOR_RATIO_SLOPE
        );

        // With 0% staking ratio:
        // - 15% to floor (minimum)
        // - 10% to ops
        // - 75% to stakers
        assertEq(toOps, 100e18); // 10% of 1000
        assertEq(toStakers, 750e18); // 75% of 1000

        // Floor price increase = 1 * 0.15 * 1000 / 1000 = 0.15
        assertEq(newFloorPrice, 115e16); // 1.15 USD per token
    }

    function testAllocate_FullStakingRatio() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 1000e18; // All tokens staked
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            floorPrice,
            OPS_RATIO,
            FLOOR_RATIO_MIN,
            FLOOR_RATIO_MAX,
            FLOOR_RATIO_SLOPE
        );

        // With 100% staking ratio:
        // - 50% to floor (maximum)
        // - 10% to ops
        // - 40% to stakers
        assertEq(toOps, 100e18); // 10% of 1000
        assertEq(toStakers, 400e18); // 40% of 1000

        // Floor price increase = 1 * 0.5 * 1000 / 1000 = 0.5
        assertEq(newFloorPrice, 15e17); // 1.5 USD per token
    }

    function testAllocate_HalfStakingRatio() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 500e18; // Half tokens staked
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            floorPrice,
            OPS_RATIO,
            FLOOR_RATIO_MIN,
            FLOOR_RATIO_MAX,
            FLOOR_RATIO_SLOPE
        );

        // With 50% staking ratio:
        // - 40% to floor (15% + 50% * 0.5)
        // - 10% to ops
        // - 50% to stakers
        assertEq(toOps, 100e18); // 10% of 1000
        assertEq(toStakers, 500e18); // 50% of 1000

        // Floor price increase = 1 * 0.4 * 1000 / 1000 = 0.4
        assertEq(newFloorPrice, 14e17); // 1.4 USD per token
    }

    function testAllocate_ZeroYield() public pure {
        uint256 yieldTokens = 0; // No yield
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 500e18; // Half tokens staked
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            floorPrice,
            OPS_RATIO,
            FLOOR_RATIO_MIN,
            FLOOR_RATIO_MAX,
            FLOOR_RATIO_SLOPE
        );

        // With 0 yield:
        assertEq(toOps, 0);
        assertEq(toStakers, 0);
        assertEq(newFloorPrice, floorPrice);
    }

    function testAllocate_Precision() public pure {
        uint256 yieldTokens = 1e18; // 1 token
        uint256 totalSupply = 1e18; // 1 total supply
        uint256 stakedSupply = 1e17; // 10% staked
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            floorPrice,
            OPS_RATIO,
            FLOOR_RATIO_MIN,
            FLOOR_RATIO_MAX,
            FLOOR_RATIO_SLOPE
        );

        // With 10% staking ratio:
        // - 20% to floor (15% + 50% * 0.1)
        // - 10% to ops
        // - 70% to stakers
        assertEq(toOps, 1e17); // 10% of 1
        assertEq(toStakers, 7e17); // 70% of 1

        // Floor price increase = 1 * 0.2 * 1 / 1 = 0.2
        assertEq(newFloorPrice, 12e17); // 1.2 USD per token
    }

    function testAllocate_ZeroTotalSupply() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 0; // No tokens in circulation
        uint256 stakedSupply = 0; // No staked tokens
        uint256 floorPrice = 1e18; // 1 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            floorPrice,
            OPS_RATIO,
            FLOOR_RATIO_MIN,
            FLOOR_RATIO_MAX,
            FLOOR_RATIO_SLOPE
        );

        // With 0 total supply:
        assertEq(toOps, 0);
        assertEq(toStakers, 0);
        assertEq(newFloorPrice, floorPrice);
    }

    function testAllocate_ZeroFloorPrice() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 500e18; // Half tokens staked
        uint256 floorPrice = 0; // 0 USD per token

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            floorPrice,
            OPS_RATIO,
            FLOOR_RATIO_MIN,
            FLOOR_RATIO_MAX,
            FLOOR_RATIO_SLOPE
        );

        // With 0 floor price:
        assertEq(toOps, 0);
        assertEq(toStakers, 0);
        assertEq(newFloorPrice, 0);
    }

    function testAllocate_CustomRatios() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 500e18; // Half tokens staked
        uint256 floorPrice = 1e18; // 1 USD per token

        // Custom ratios
        uint256 customOpsRatio = 0.05e18; // 5%
        uint256 customFloorMin = 0.1e18; // 10%
        uint256 customFloorMax = 0.4e18; // 40%
        uint256 customFloorIncrease = 0.25e18; // 25%

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            floorPrice,
            customOpsRatio,
            customFloorMin,
            customFloorMax,
            customFloorIncrease
        );

        // With 50% staking ratio and custom ratios:
        // - 25% to floor (10% + 40% * 0.5)
        // - 5% to ops
        // - 70% to stakers
        assertEq(toOps, 50e18); // 5% of 1000
        assertEq(toStakers, 725e18); // 70% of 1000

        // Floor price increase = 1 * 0.25 * 1000 / 1000 = 0.25
        assertEq(newFloorPrice, 1.225e18); // 1.225 USD per token
    }

    function testAllocate_CustomRatios_2() public pure {
        uint256 yieldTokens = 100e18; // 100 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 500e18; // Half tokens staked
        uint256 floorPrice = 1e18; // 1 USD per token

        // Custom ratios
        uint256 customOpsRatio = 0.05e18; // 5%
        uint256 customFloorMin = 0.1e18; // 10%
        uint256 customFloorMax = 0.4e18; // 40%
        uint256 customFloorSlope = 0.45e18; // 0.45

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            floorPrice,
            customOpsRatio,
            customFloorMin,
            customFloorMax,
            customFloorSlope
        );

        // With 50% staking ratio and custom ratios:
        // - 25% to floor (10% + 40% * 0.5)
        // - 5% to ops
        // - 70% to stakers
        assertEq(toOps, 5e18, "toOps"); // 5% of 1000
        assertEq(toStakers, 62.5e18, "toStakers"); // 62.5% of 1000

        // Floor price increase = 1 * 0.25 * 1000 / 1000 = 0.25
        assertEq(newFloorPrice, 1.0325e18, "newFloorPrice"); // 1.0325 USD per token
    }

    function testAllocate_CustomRatios_3() public pure {
        uint256 yieldTokens = 100e18; // 100 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 900e18; // 90% tokens staked
        uint256 floorPrice = 1e18; // 1 USD per token

        // Custom ratios
        uint256 customOpsRatio = 0.05e18; // 5%
        uint256 customFloorMin = 0.15e18; // 15%
        uint256 customFloorMax = 0.5e18; // 40%
        uint256 customFloorSlope = 0.45e18; // 0.45

        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            floorPrice,
            customOpsRatio,
            customFloorMin,
            customFloorMax,
            customFloorSlope
        );

        // With 50% staking ratio and custom ratios:
        // - 25% to floor (10% + 40% * 0.5)
        // - 5% to ops
        // - 70% to stakers
        assertEq(toOps, 5e18, "toOps"); // 5% of 1000
        assertEq(toStakers, 45e18, "toStakers"); // 45% of 1000

        // Floor price increase = 1 * 0.25 * 1000 / 1000 = 0.25
        assertEq(newFloorPrice, 1.05e18, "newFloorPrice"); // 1.05 USD per token
    }

    function testAllocate_EdgeCases() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 1000e18; // All tokens staked
        uint256 floorPrice = 1e18; // 1 USD per token

        // Test with maximum possible ratios
        (uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            floorPrice,
            0.1e18, // 10% ops
            0.15e18, // 15% floor min
            0.5e18, // 50% floor max
            0.5e18 // 50% floor increase
        );

        // Should handle maximum ratios without overflow
        assertEq(toOps, 100e18); // 10% to ops
        assertEq(toStakers, 400e18); // 0% to stakers
        assertEq(newFloorPrice, 1.5e18); // 1.5x floor price
    }
}
