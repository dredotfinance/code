// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";

contract AppBurnerTest is BaseTest {
    function setUp() public {
        setUpBaseTest();
    }

    function test_Initialize() public view {
        assertEq(address(burner.appOracle()), address(appOracle));
        assertEq(address(burner.app()), address(app));
    }

    function test_CalculateFloorUpdate_ZeroAmount() public view {
        uint256 newFloorPrice = burner.calculateFloorUpdate(0, 1000e18, 1e18);
        assertEq(newFloorPrice, 1e18, "Floor price should remain unchanged with zero burn amount");
    }

    function test_CalculateFloorUpdate_ZeroFloorPrice() public view {
        uint256 newFloorPrice = burner.calculateFloorUpdate(100e18, 1000e18, 0);
        assertEq(newFloorPrice, 0, "Floor price should remain zero with zero initial floor price");
    }

    function test_CalculateFloorUpdate_ZeroTotalSupply() public view {
        uint256 newFloorPrice = burner.calculateFloorUpdate(100e18, 0, 1e18);
        assertEq(newFloorPrice, 1e18, "Floor price should remain unchanged with zero total supply");
    }

    function test_CalculateFloorUpdate_50PercentBurn() public view {
        // Test burning 50% of supply
        uint256 newFloorPrice = burner.calculateFloorUpdate(500e18, 1000e18, 1e18);
        assertEq(newFloorPrice, 2e18, "Floor price should double with 50% burn");
    }

    function test_CalculateFloorUpdate_90PercentBurn() public view {
        // Test burning 90% of supply
        uint256 newFloorPrice = burner.calculateFloorUpdate(900e18, 1000e18, 1e18);
        assertEq(newFloorPrice, 10e18, "Floor price should 10x with 90% burn");
    }

    function test_CalculateFloorUpdate_Precision() public view {
        // Test with small amounts to verify precision
        uint256 newFloorPrice = burner.calculateFloorUpdate(1e18, 1000e18, 1e18);
        // Calculate expected price: 1e18 * (10000 / 9999)
        uint256 expectedPrice = uint256(1e18 * 10000) / 9999;
        assertApproxEqRel(newFloorPrice, expectedPrice, 0.001e18, "Floor price should increase by 0.1% with 0.1% burn");
    }

    function test_Burn() public {
        // Setup: Mint RZR tokens to burner
        vm.startPrank(owner);

        app.mint(address(owner), 1000e18);
        app.mint(address(burner), 1000e18);

        treasury.enable(address(mockQuoteToken));
        mockQuoteToken.mint(address(treasury), 10000e18);

        // Execute burn
        burner.burn();

        // Verify floor price update
        uint256 newFloorPrice = appOracle.getTokenPrice();
        assertApproxEqRel(newFloorPrice, 2e18, 0.001e18, "Floor price should update correctly after burn");

        // Verify RZR balance is zero after burn
        assertEq(app.balanceOf(address(burner)), 0, "All RZR tokens should be burned");
        vm.stopPrank();
    }

    function test_Burn_NoTokens() public {
        vm.startPrank(owner);
        uint256 initialFloorPrice = appOracle.getTokenPrice();

        // Execute burn with no tokens
        burner.burn();

        // Verify floor price remains unchanged
        uint256 newFloorPrice = appOracle.getTokenPrice();
        assertEq(newFloorPrice, initialFloorPrice, "Floor price should remain unchanged with no tokens to burn");
        vm.stopPrank();
    }

    function test_Burn_OnlyExecutor() public {
        vm.startPrank(user1); // user1 is not an executor
        vm.expectRevert("UNAUTHORIZED");
        burner.burn();
        vm.stopPrank();
    }

    function test_Burn_WithLargeAmount() public {
        vm.startPrank(owner);
        // Mint a large amount to test precision with big numbers
        app.mint(address(owner), 1);
        app.mint(address(burner), 1_000_000e18);

        // Execute burn
        vm.expectRevert();
        burner.burn();

        // // Verify floor price update
        // uint256 newFloorPrice = appOracle.getTokenPrice();
        // assertEq(newFloorPrice, 1e22, "Floor price should update correctly with large burn amount");

        // // Verify RZR balance is zero after burn
        // assertEq(app.balanceOf(address(burner)), 0, "All RZR tokens should be burned");
        // vm.stopPrank();
    }
}
