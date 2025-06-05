// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/libraries/YieldLogic.sol";

contract YieldLogicTest is Test {
    using YieldLogic for uint256;

    // Constants for testing
    uint256 constant EPOCHS_PER_YEAR = 1095; // 8-hour epochs
    uint256 constant PRECISION = 1e18;

    function testZeroSupply() public {
        (uint256 apr, uint256 epochMint) = YieldLogic.calcEpoch(1000e18, 0, EPOCHS_PER_YEAR);
        assertEq(apr, 0, "APR should be 0 for zero supply");
        assertEq(epochMint, 0, "Epoch mint should be 0 for zero supply");
    }

    function testBackingRatioBelowOne() public {
        // PCV = 500e18, Supply = 1000e18 -> beta = 0.5
        (uint256 apr, uint256 epochMint) = YieldLogic.calcEpoch(500e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 0, "APR should be 0 for beta < 1.0");
        assertEq(epochMint, 0, "Epoch mint should be 0 for beta < 1.0");
    }

    function testBackingRatioOneToOnePointFive() public {
        // Test beta = 1.0 (minimum for non-zero APR)
        (uint256 apr, uint256 epochMint) = YieldLogic.calcEpoch(1000e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 0, "APR should be 0 for beta = 1.0");

        // Test beta = 1.25 (middle of first band)
        (apr, epochMint) = YieldLogic.calcEpoch(1250e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 250, "APR should be 250% for beta = 1.25");

        // Test beta = 1.5 (end of first band)
        (apr, epochMint) = YieldLogic.calcEpoch(1500e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 500, "APR should be 500% for beta = 1.5");
    }

    function testBackingRatioOnePointFiveToTwo() public {
        // Test beta = 1.5 (start of second band)
        (uint256 apr, uint256 epochMint) = YieldLogic.calcEpoch(1500e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 500, "APR should be 500% for beta = 1.5");

        // Test beta = 1.75 (middle of second band)
        (apr, epochMint) = YieldLogic.calcEpoch(1750e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 875, "APR should be 875% for beta = 1.75");

        // Test beta = 2.0 (end of second band)
        (apr, epochMint) = YieldLogic.calcEpoch(2000e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 1250, "APR should be 500% for beta = 2.0");
    }

    function testBackingRatioTwoToTwoPointFive() public {
        // Test beta = 2.0 (start of third band)
        (uint256 apr, uint256 epochMint) = YieldLogic.calcEpoch(2000e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 1250, "APR should be 500% for beta = 2.0");

        // Test beta = 2.25 (middle of third band)
        (apr, epochMint) = YieldLogic.calcEpoch(2250e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 1625, "APR should be 1625% for beta = 2.25");

        // Test beta = 2.5 (end of third band)
        (apr, epochMint) = YieldLogic.calcEpoch(2500e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 2000, "APR should be 2000% for beta = 2.5");
    }

    function testBackingRatioAboveTwoPointFive() public {
        // Test beta = 2.5 (minimum for max APR)
        (uint256 apr, uint256 epochMint) = YieldLogic.calcEpoch(2500e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 2000, "APR should be 2000% for beta = 2.5");

        // Test beta = 3.0 (above max)
        (apr, epochMint) = YieldLogic.calcEpoch(3000e18, 1000e18, EPOCHS_PER_YEAR);
        assertEq(apr, 2000, "APR should be capped at 2000% for beta > 2.5");
    }

    function testEpochMintCalculation() public {
        uint256 supply = 1000e18;
        uint256 pcv = 2500e18; // beta = 2.5 for max APR

        (uint256 apr, uint256 epochMint) = YieldLogic.calcEpoch(pcv, supply, EPOCHS_PER_YEAR);

        // Expected epoch mint = (supply * apr) / (100 * epochsPerYear)
        // = (1000e18 * 2000) / (100 * 1095)
        // ≈ 18.26e18 tokens per epoch
        uint256 expectedEpochMint = (supply * 2000) / (100 * EPOCHS_PER_YEAR);

        assertEq(apr, 2000, "APR should be 2000%");
        assertEq(epochMint, expectedEpochMint, "Epoch mint calculation incorrect");
    }

    function testDifferentEpochsPerYear() public {
        uint256 supply = 1000e18;
        uint256 pcv = 2500e18; // beta = 2.5 for max APR
        uint256 customEpochsPerYear = 365; // Daily epochs

        (uint256 apr, uint256 epochMint) = YieldLogic.calcEpoch(pcv, supply, customEpochsPerYear);

        // Expected epoch mint = (supply * apr) / (100 * epochsPerYear)
        // = (1000e18 * 2000) / (100 * 365)
        // ≈ 54.79e18 tokens per epoch
        uint256 expectedEpochMint = (supply * 2000) / (100 * customEpochsPerYear);

        assertEq(apr, 2000, "APR should be 2000%");
        assertEq(epochMint, expectedEpochMint, "Epoch mint calculation incorrect for custom epochs");
    }

    function testPrecisionHandling() public {
        // Test with very small numbers
        uint256 tinySupply = 1e10; // 0.00000001 tokens
        uint256 tinyPcv = 2e10; // beta = 2.0

        (uint256 apr, uint256 epochMint) = YieldLogic.calcEpoch(tinyPcv, tinySupply, EPOCHS_PER_YEAR);
        assertEq(apr, 1250, "APR should be 1250% for beta = 2.0 with tiny numbers");
        assertGt(epochMint, 0, "Epoch mint should be non-zero for tiny numbers");

        // Test with very large numbers
        uint256 hugeSupply = 1e30;
        uint256 hugePcv = 25e30; // beta = 2.5

        (apr, epochMint) = YieldLogic.calcEpoch(hugePcv, hugeSupply, EPOCHS_PER_YEAR);
        assertEq(apr, 2000, "APR should be 2000% for beta = 2.5 with huge numbers");
        assertGt(epochMint, 0, "Epoch mint should be non-zero for huge numbers");
    }
}
