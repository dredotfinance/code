// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/oracles/TwapOracle.sol";
import "../contracts/mocks/MockOracle.sol";

contract TwapOracleTest is Test {
    TwapOracle public twapOracle;
    MockOracle public mockOracle;
    uint256 public constant WINDOW_SIZE = 12 hours;

    function setUp() public {
        vm.warp(100000);

        // Create mock oracle with 18 decimals
        mockOracle = new MockOracle(1e18);

        // Create TWAP oracle with 1 hour window
        twapOracle = new TwapOracle(mockOracle, 1 hours, WINDOW_SIZE, address(this));
    }

    function test_InitialState() public view {
        assertEq(twapOracle.windowSize(), WINDOW_SIZE, "Window size should be set correctly");
        assertEq(address(twapOracle.oracle()), address(mockOracle), "Oracle address should be set correctly");
        // assertEq(twapOracle.decimals(), 18, "Decimals should match oracle");
    }

    function test_UpdatePrice() public {
        // Initial price is 1e18
        assertEq(twapOracle.getPrice(), 1e18, "Initial price should be 1e18");

        // Update price to 2e18
        mockOracle.setPrice(2e18);
        twapOracle.update();
        assertEq(twapOracle.getPrice(), 1.5e18, "Price should update to 1.5e18");

        // Try to update too quickly
        vm.expectRevert("Too early to update");
        twapOracle.update();
    }

    function test_TwapCalculation() public {
        // Set initial price
        mockOracle.setPrice(1e18);
        twapOracle.update();

        // Move time forward 1 hours
        vm.warp(block.timestamp + 1 hours);

        // Update price to 2e18
        mockOracle.setPrice(2e18);
        twapOracle.update();

        // Move time forward 1 hours
        vm.warp(block.timestamp + 1 hours);

        // TWAP should be average of 1e18 + 1e18 + 2e18 = 1.3e18
        uint256 twap = twapOracle.getTwap();
        assertApproxEqRel(twap, 1.3e18, 0.1e18, "TWAP should be 1.3e18");
    }

    function test_MultipleUpdates() public {
        // Set initial price
        mockOracle.setPrice(1e18);
        twapOracle.update();
        vm.warp(block.timestamp + 1 hours);

        // Update price multiple times
        for (uint256 i = 0; i < 150; i++) {
            vm.warp(block.timestamp + 1 hours);
            mockOracle.setPrice(2e18 + i * 1e17); // Increase price each time
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
}
