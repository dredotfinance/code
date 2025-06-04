// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/oracles/AverageCappedOracle.sol";
import "../contracts/mocks/MockOracle.sol";

contract AverageCappedOracleTest is Test {
    AverageCappedOracle public averageOracle;
    MockOracle public oracle0;
    MockOracle public oracle1;

    function setUp() public {
        // Deploy mock oracles with initial prices
        oracle0 = new MockOracle(1e18); // $1.00
        oracle1 = new MockOracle(1e18); // $1.00

        // Deploy AverageCappedOracle with 5% max deviation (500 basis points)
        averageOracle = new AverageCappedOracle(IOracle(address(oracle0)), IOracle(address(oracle1)), 500);
    }

    function test_Constructor() public view {
        // Verify initial state
        assertEq(address(averageOracle.oracle0()), address(oracle0), "Oracle0 address should be set");
        assertEq(address(averageOracle.oracle1()), address(oracle1), "Oracle1 address should be set");
        assertEq(averageOracle.maxDeviationPercent(), 500, "Max deviation should be 5%");
    }

    function test_ConstructorReverts() public {
        // Test zero address for oracle0
        vm.expectRevert("Invalid oracle0 address");
        new AverageCappedOracle(IOracle(address(0)), IOracle(address(oracle1)), 500);

        // Test zero address for oracle1
        vm.expectRevert("Invalid oracle1 address");
        new AverageCappedOracle(IOracle(address(oracle0)), IOracle(address(0)), 500);

        // Test zero max deviation
        vm.expectRevert("Invalid max deviation");
        new AverageCappedOracle(IOracle(address(oracle0)), IOracle(address(oracle1)), 0);

        // Test max deviation > 10%
        vm.expectRevert("Invalid max deviation");
        new AverageCappedOracle(IOracle(address(oracle0)), IOracle(address(oracle1)), 1001);
    }

    function test_GetPrice() public {
        // Test equal prices
        assertEq(averageOracle.getPrice(), 1e18, "Average price should be $1.00 - 1");

        // Test prices within deviation limit
        oracle0.setPrice(1.02e18); // $1.02
        oracle1.setPrice(0.98e18); // $0.98
        assertEq(averageOracle.getPrice(), 1e18, "Average price should be $1.00 - 2");

        // Test prices at deviation limit
        oracle0.setPrice(1.05e18); // $1.05
        oracle1.setPrice(0.95e18); // $0.95
        vm.expectRevert(abi.encodeWithSelector(AverageCappedOracle.ExcessiveDeviation.selector, 1.05e18, 0.95e18, 1052));
        averageOracle.getPrice();
    }

    function test_GetPriceReverts() public {
        // Test prices exceeding deviation limit
        oracle0.setPrice(1.06e18); // $1.06
        oracle1.setPrice(0.94e18); // $0.94
        vm.expectRevert(
            abi.encodeWithSelector(
                AverageCappedOracle.ExcessiveDeviation.selector,
                1.06e18,
                0.94e18,
                1276 // Deviation in basis points
            )
        );
        averageOracle.getPrice();
    }

    function test_GetPriceWithDifferentScales() public {
        // Test with different price scales
        oracle0.setPrice(100e18); // $100.00
        oracle1.setPrice(102e18); // $102.00
        assertEq(averageOracle.getPrice(), 101e18, "Average price should be $101.00");

        // Test with very small prices
        oracle0.setPrice(1e10); // $0.0000000001
        oracle1.setPrice(1.02e10); // $0.000000000102
        assertEq(averageOracle.getPrice(), 1.01e10, "Average price should be $0.000000000101");
    }

    function test_GetPriceWithZeroPrice() public {
        // Test with zero price from one oracle
        oracle0.setPrice(0);
        oracle1.setPrice(1e18);
        vm.expectRevert(); // Division by zero
        averageOracle.getPrice();
    }

    function test_GetPriceWithLargeNumbers() public {
        // Test with very large numbers
        oracle0.setPrice(type(uint256).max / 2);
        oracle1.setPrice(type(uint256).max / 2);
        assertEq(averageOracle.getPrice(), type(uint256).max / 2, "Average should handle large numbers");
    }
}
