// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../contracts/oracles/CappedOracle.sol";
import "../../contracts/mocks/MockOracle.sol";

contract CappedOracleTest is Test {
    CappedOracle public cappedOracle;
    MockOracle public mockOracle;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    uint256 public constant PRICE_1E18 = 1e18;
    uint256 public constant PRICE_2E18 = 2e18;
    uint256 public constant PRICE_0_5E18 = 0.5e18;
    uint256 public constant MAX_UPPER_BOUND = 2e18;
    uint256 public constant MAX_LOWER_BOUND = 0.5e18;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock oracle with initial price
        mockOracle = new MockOracle(PRICE_1E18);

        // Deploy capped oracle
        cappedOracle = new CappedOracle(IOracle(address(mockOracle)), MAX_UPPER_BOUND, MAX_LOWER_BOUND);

        vm.stopPrank();

        // Label contracts for better trace output
        vm.label(address(cappedOracle), "CappedOracle");
        vm.label(address(mockOracle), "MockOracle");
    }

    function test_Constructor_ValidParameters() public {
        // Test that constructor works with valid parameters
        CappedOracle newCappedOracle = new CappedOracle(IOracle(address(mockOracle)), MAX_UPPER_BOUND, MAX_LOWER_BOUND);

        assertEq(address(newCappedOracle.oracle()), address(mockOracle));
        assertEq(newCappedOracle.maxUpperBound(), MAX_UPPER_BOUND);
        assertEq(newCappedOracle.maxLowerBound(), MAX_LOWER_BOUND);
    }

    function test_Constructor_RevertOnZeroOracleAddress() public {
        // Test that constructor reverts with zero oracle address
        vm.expectRevert("Invalid oracle address");
        new CappedOracle(IOracle(address(0)), MAX_UPPER_BOUND, MAX_LOWER_BOUND);
    }

    function test_Constructor_RevertOnZeroMaxUpperBound() public {
        // Test that constructor reverts with zero max upper bound
        vm.expectRevert("Invalid max upper bound");
        new CappedOracle(IOracle(address(mockOracle)), 0, MAX_LOWER_BOUND);
    }

    function test_Constructor_RevertOnZeroMaxLowerBound() public {
        // Test that constructor reverts with zero max lower bound
        vm.expectRevert("Invalid max lower bound");
        new CappedOracle(IOracle(address(mockOracle)), MAX_UPPER_BOUND, 0);
    }

    function test_GetPrice_WithinBounds() public {
        // Test that getPrice returns correct price when within bounds
        uint256 price = cappedOracle.getPrice();
        assertEq(price, PRICE_1E18);
    }

    function test_GetPrice_AtUpperBound() public {
        // Test that getPrice works when price is exactly at upper bound
        mockOracle.setPrice(MAX_UPPER_BOUND);
        uint256 price = cappedOracle.getPrice();
        assertEq(price, MAX_UPPER_BOUND);
    }

    function test_GetPrice_AtLowerBound() public {
        // Test that getPrice works when price is exactly at lower bound
        mockOracle.setPrice(MAX_LOWER_BOUND);
        uint256 price = cappedOracle.getPrice();
        assertEq(price, MAX_LOWER_BOUND);
    }

    function test_GetPrice_RevertOnExceedsUpperBound() public {
        // Test that getPrice reverts when price exceeds upper bound
        mockOracle.setPrice(MAX_UPPER_BOUND + 1);
        vm.expectRevert("Price exceeds upper bound");
        cappedOracle.getPrice();
    }

    function test_GetPrice_RevertOnExceedsLowerBound() public {
        // Test that getPrice reverts when price is below lower bound
        mockOracle.setPrice(MAX_LOWER_BOUND - 1);
        vm.expectRevert("Price exceeds lower bound");
        cappedOracle.getPrice();
    }

    function test_GetPrice_ZeroPrice() public {
        // Test edge case with zero price
        mockOracle.setPrice(0);
        vm.expectRevert("Price exceeds lower bound");
        cappedOracle.getPrice();
    }

    function test_GetPrice_VeryHighPrice() public {
        // Test edge case with very high price
        mockOracle.setPrice(type(uint256).max);
        vm.expectRevert("Price exceeds upper bound");
        cappedOracle.getPrice();
    }

    function test_GetPrice_DynamicPriceChanges() public {
        // Test that price changes are properly handled
        uint256[] memory testPrices = new uint256[](5);
        testPrices[0] = MAX_LOWER_BOUND; // Should work
        testPrices[1] = PRICE_1E18; // Should work
        testPrices[2] = MAX_UPPER_BOUND; // Should work
        testPrices[3] = MAX_LOWER_BOUND - 1; // Should revert
        testPrices[4] = MAX_UPPER_BOUND + 1; // Should revert

        for (uint256 i = 0; i < testPrices.length; i++) {
            mockOracle.setPrice(testPrices[i]);

            if (i < 3) {
                // First 3 prices should work
                uint256 price = cappedOracle.getPrice();
                assertEq(price, testPrices[i]);
            } else {
                // Last 2 prices should revert
                if (i == 3) {
                    vm.expectRevert("Price exceeds lower bound");
                } else {
                    vm.expectRevert("Price exceeds upper bound");
                }
                cappedOracle.getPrice();
            }
        }
    }

    function test_GetPrice_FromDifferentCaller() public {
        // Test that getPrice works when called from different address
        vm.prank(user);
        uint256 price = cappedOracle.getPrice();
        assertEq(price, PRICE_1E18);
    }

    function test_StateVariables_Immutable() public {
        // Test that state variables are correctly set and immutable
        assertEq(address(cappedOracle.oracle()), address(mockOracle));
        assertEq(cappedOracle.maxUpperBound(), MAX_UPPER_BOUND);
        assertEq(cappedOracle.maxLowerBound(), MAX_LOWER_BOUND);

        // Verify these don't change after multiple calls
        cappedOracle.getPrice();
        cappedOracle.getPrice();

        assertEq(address(cappedOracle.oracle()), address(mockOracle));
        assertEq(cappedOracle.maxUpperBound(), MAX_UPPER_BOUND);
        assertEq(cappedOracle.maxLowerBound(), MAX_LOWER_BOUND);
    }

    function test_Integration_WithRealisticPrices() public {
        // Test with realistic price scenarios
        uint256[] memory realisticPrices = new uint256[](4);
        realisticPrices[0] = 0.75e18; // 75 cents - should work
        realisticPrices[1] = 1.25e18; // $1.25 - should work
        realisticPrices[2] = 0.25e18; // 25 cents - should revert (below lower bound)
        realisticPrices[3] = 3e18; // $3 - should revert (above upper bound)

        for (uint256 i = 0; i < realisticPrices.length; i++) {
            mockOracle.setPrice(realisticPrices[i]);

            if (i < 2) {
                // First 2 prices should work
                uint256 price = cappedOracle.getPrice();
                assertEq(price, realisticPrices[i]);
            } else {
                // Last 2 prices should revert
                if (i == 2) {
                    vm.expectRevert("Price exceeds lower bound");
                } else {
                    vm.expectRevert("Price exceeds upper bound");
                }
                cappedOracle.getPrice();
            }
        }
    }

    function test_EdgeCase_BoundsEqual() public {
        // Test edge case where upper and lower bounds are equal
        uint256 equalBound = 1e18;
        CappedOracle equalBoundsOracle = new CappedOracle(IOracle(address(mockOracle)), equalBound, equalBound);

        // Price exactly at bound should work
        mockOracle.setPrice(equalBound);
        uint256 price = equalBoundsOracle.getPrice();
        assertEq(price, equalBound);

        // Price above bound should revert
        mockOracle.setPrice(equalBound + 1);
        vm.expectRevert("Price exceeds upper bound");
        equalBoundsOracle.getPrice();

        // Price below bound should revert
        mockOracle.setPrice(equalBound - 1);
        vm.expectRevert("Price exceeds lower bound");
        equalBoundsOracle.getPrice();
    }

    function test_GasUsage_Optimization() public {
        // Test gas usage for getPrice calls
        uint256 gasBefore = gasleft();
        cappedOracle.getPrice();
        uint256 gasUsed = gasBefore - gasleft();

        // Verify gas usage is reasonable (should be low for a simple view function)
        assertLt(gasUsed, 20000); // Adjusted threshold based on actual gas usage

        // Test gas usage with different prices
        mockOracle.setPrice(MAX_UPPER_BOUND);
        gasBefore = gasleft();
        cappedOracle.getPrice();
        gasUsed = gasBefore - gasleft();
        assertLt(gasUsed, 20000);
    }
}
