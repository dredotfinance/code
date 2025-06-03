// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/oracles/TwapOracle.sol";
import "../contracts/mocks/MockAggregatorV3.sol";

contract TwapOracleTest is Test {
    TwapOracle public twapOracle;
    MockAggregatorV3 public mockOracle;
    uint256 public constant WINDOW_SIZE = 1 hours;

    function setUp() public {
        // Create mock oracle with 18 decimals
        mockOracle = new MockAggregatorV3(18, 1e18);

        // Create TWAP oracle with 1 hour window
        twapOracle = new TwapOracle(mockOracle, WINDOW_SIZE, 1 hours, address(this));
    }

    function test_InitialState() public {
        assertEq(twapOracle.windowSize(), WINDOW_SIZE, "Window size should be set correctly");
        assertEq(address(twapOracle.oracle()), address(mockOracle), "Oracle address should be set correctly");
        assertEq(twapOracle.decimals(), 18, "Decimals should match oracle");
    }

    function test_UpdatePrice() public {
        // Initial price is 1e18
        assertEq(twapOracle.latestAnswer(), 1e18, "Initial price should be 1e18");

        // Update price to 2e18
        mockOracle.setPrice(2e18);
        twapOracle.update();
        assertEq(twapOracle.latestAnswer(), 2e18, "Price should update to 2e18");

        // Try to update too quickly
        vm.expectRevert("Too early to update");
        twapOracle.update();
    }

    function test_TwapCalculation() public {
        // Set initial price
        mockOracle.setPrice(1e18);
        twapOracle.update();

        // Move time forward 30 minutes
        vm.warp(block.timestamp + 30 minutes);

        // Update price to 2e18
        mockOracle.setPrice(2e18);
        twapOracle.update();

        // Move time forward 30 minutes
        vm.warp(block.timestamp + 30 minutes);

        // TWAP should be average of 1e18 and 2e18 = 1.5e18
        int256 twap = twapOracle.getTwap();
        assertEq(twap, 1.5e18, "TWAP should be 1.5e18");
    }

    function test_MultipleUpdates() public {
        // Set initial price
        mockOracle.setPrice(1e18);
        twapOracle.update();

        // Update price multiple times
        for (uint256 i = 0; i < 5; i++) {
            vm.warp(block.timestamp + 1 hours);
            mockOracle.setPrice(int256(2e18 + i * 1e17)); // Increase price each time
            twapOracle.update();
        }

        // Verify we have multiple observations
        TwapOracle.Observation memory observation = twapOracle.observations(0);
        assertGt(observation.timestamp, 0, "Should have observations");
    }

    function test_ZeroPrice() public {
        // Set price to 0
        mockOracle.setPrice(0);

        // Update should fail
        vm.expectRevert("Invalid price");
        twapOracle.update();
    }

    function test_DescriptionAndVersion() public {
        assertEq(twapOracle.version(), 1, "Version should be 1");
        assertEq(
            twapOracle.description(),
            string.concat("TWAP Oracle for ", mockOracle.description()),
            "Description should include oracle description"
        );
    }
}
