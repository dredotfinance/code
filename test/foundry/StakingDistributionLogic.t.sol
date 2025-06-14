// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../contracts/libraries/StakingDistributionLogic.sol";

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

        (uint256 toStakers, uint256 toOps, uint256 toBurn) = StakingDistributionLogic.allocate(
            yieldTokens, totalSupply, stakedSupply, OPS_RATIO, FLOOR_RATIO_MIN, FLOOR_RATIO_MAX, FLOOR_RATIO_SLOPE
        );

        // With 0% staking ratio:
        // - 15% to floor (minimum) -> to burn
        // - 10% to ops
        // - 75% to stakers
        assertEq(toOps, 100e18, "toOps"); // 10% of 1000
        assertEq(toStakers, 750e18, "toStakers"); // 75% of 1000
        assertEq(toBurn, 150e18, "toBurn"); // 15% of 1000
    }

    function testAllocate_FullStakingRatio() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 1000e18; // All tokens staked

        (uint256 toStakers, uint256 toOps, uint256 toBurn) = StakingDistributionLogic.allocate(
            yieldTokens, totalSupply, stakedSupply, OPS_RATIO, FLOOR_RATIO_MIN, FLOOR_RATIO_MAX, FLOOR_RATIO_SLOPE
        );

        // With 100% staking ratio:
        // - 50% to floor (maximum) -> to burn
        // - 10% to ops
        // - 40% to stakers
        assertEq(toOps, 100e18, "toOps"); // 10% of 1000
        assertEq(toStakers, 400e18, "toStakers"); // 40% of 1000
        assertEq(toBurn, 500e18, "toBurn"); // 50% of 1000
    }

    function testAllocate_HalfStakingRatio() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 500e18; // Half tokens staked

        (uint256 toStakers, uint256 toOps, uint256 toBurn) = StakingDistributionLogic.allocate(
            yieldTokens, totalSupply, stakedSupply, OPS_RATIO, FLOOR_RATIO_MIN, FLOOR_RATIO_MAX, FLOOR_RATIO_SLOPE
        );

        // With 50% staking ratio:
        // - 40% to floor (15% + 50% * 0.5) -> to burn
        // - 10% to ops
        // - 50% to stakers
        assertEq(toOps, 100e18, "toOps"); // 10% of 1000
        assertEq(toStakers, 500e18, "toStakers"); // 50% of 1000
        assertEq(toBurn, 400e18, "toBurn"); // 40% of 1000
    }

    function testAllocate_ZeroYield() public pure {
        uint256 yieldTokens = 0; // No yield
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 500e18; // Half tokens staked

        (uint256 toStakers, uint256 toOps, uint256 toBurn) = StakingDistributionLogic.allocate(
            yieldTokens, totalSupply, stakedSupply, OPS_RATIO, FLOOR_RATIO_MIN, FLOOR_RATIO_MAX, FLOOR_RATIO_SLOPE
        );

        // With 0 yield:
        assertEq(toOps, 0, "toOps");
        assertEq(toStakers, 0, "toStakers");
        assertEq(toBurn, 0, "toBurn");
    }

    function testAllocate_Precision() public pure {
        uint256 yieldTokens = 1e18; // 1 token
        uint256 totalSupply = 1e18; // 1 total supply
        uint256 stakedSupply = 1e17; // 10% staked

        (uint256 toStakers, uint256 toOps, uint256 toBurn) = StakingDistributionLogic.allocate(
            yieldTokens, totalSupply, stakedSupply, OPS_RATIO, FLOOR_RATIO_MIN, FLOOR_RATIO_MAX, FLOOR_RATIO_SLOPE
        );

        // With 10% staking ratio:
        // - 20% to floor (15% + 50% * 0.1) -> to burn
        // - 10% to ops
        // - 70% to stakers
        assertEq(toOps, 1e17, "toOps"); // 10% of 1
        assertEq(toStakers, 7e17, "toStakers"); // 70% of 1
        assertEq(toBurn, 2e17, "toBurn"); // 20% of 1
    }

    function testAllocate_ZeroTotalSupply() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 0; // No tokens in circulation
        uint256 stakedSupply = 0; // No staked tokens

        (uint256 toStakers, uint256 toOps, uint256 toBurn) = StakingDistributionLogic.allocate(
            yieldTokens, totalSupply, stakedSupply, OPS_RATIO, FLOOR_RATIO_MIN, FLOOR_RATIO_MAX, FLOOR_RATIO_SLOPE
        );

        // With 0 total supply:
        assertEq(toOps, 0, "toOps");
        assertEq(toStakers, 0, "toStakers");
        assertEq(toBurn, 0, "toBurn");
    }

    function testAllocate_CustomRatios() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 500e18; // Half tokens staked

        // Custom ratios
        uint256 customOpsRatio = 0.05e18; // 5%
        uint256 customFloorMin = 0.1e18; // 10%
        uint256 customFloorMax = 0.4e18; // 40%
        uint256 customFloorSlope = 0.25e18; // 25%

        (uint256 toStakers, uint256 toOps, uint256 toBurn) = StakingDistributionLogic.allocate(
            yieldTokens, totalSupply, stakedSupply, customOpsRatio, customFloorMin, customFloorMax, customFloorSlope
        );

        // With 50% staking ratio and custom ratios:
        // - 25% to floor (10% + 40% * 0.5) -> to burn
        // - 5% to ops
        // - 70% to stakers
        assertEq(toOps, 50e18, "toOps"); // 5% of 1000
        assertEq(toStakers, 725e18, "toStakers"); // 70% of 1000
        assertEq(toBurn, 225e18, "toBurn"); // 25% of 1000
    }

    function testAllocate_EdgeCases() public pure {
        uint256 yieldTokens = 1000e18; // 1000 tokens
        uint256 totalSupply = 1000e18; // 1000 total supply
        uint256 stakedSupply = 1000e18; // All tokens staked

        // Test with maximum possible ratios
        (uint256 toStakers, uint256 toOps, uint256 toBurn) = StakingDistributionLogic.allocate(
            yieldTokens,
            totalSupply,
            stakedSupply,
            0.1e18, // 10% ops
            0.15e18, // 15% floor min
            0.5e18, // 50% floor max
            0.5e18 // 50% floor slope
        );

        // Should handle maximum ratios without overflow
        assertEq(toOps, 100e18, "toOps"); // 10% to ops
        assertEq(toStakers, 400e18, "toStakers"); // 40% to stakers
        assertEq(toBurn, 500e18, "toBurn"); // 50% to burn
    }
}
