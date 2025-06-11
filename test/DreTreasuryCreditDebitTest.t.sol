// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./BaseTest.sol";

contract AppTreasuryCreditDebitTest is BaseTest {
    function setUp() public {
        setUpBaseTest();
        vm.startPrank(owner);

        dreAuthority.addReserveDepositor(owner);
        dreAuthority.addPolicy(owner);
        dreAuthority.addVault(owner);
        dreAuthority.addReserveManager(owner);
        dreAuthority.addRewardManager(owner);
        dreAuthority.addReserveDepositor(owner);
    }

    function test_InitialState() public view {
        assertEq(treasury.creditReserves(), 0);
        assertEq(treasury.unbackedSupply(), 0);
        assertEq(treasury.actualReserves(), 0);
        assertEq(treasury.actualSupply(), 0);
    }

    function test_SetCreditReserves() public {
        // Set credit reserves
        treasury.setCreditReserves(100e18);

        // Verify values are set correctly
        assertEq(treasury.creditReserves(), 100e18);

        // Verify actual reserves calculation
        uint256 expectedActualReserves = treasury.totalReserves() - 100e18;
        assertEq(treasury.actualReserves(), expectedActualReserves);
    }

    function test_SetUnbackedSupply() public {
        app.mint(owner, 500e18);

        // Set unbacked supply
        treasury.setUnbackedSupply(200e18);

        // Verify values are set correctly
        assertEq(treasury.unbackedSupply(), 200e18);

        // Verify actual supply calculation
        uint256 expectedActualSupply = app.totalSupply() - 200e18;
        assertEq(treasury.totalSupply(), expectedActualSupply);
    }

    function test_BackingRatioWithCreditDebit() public {
        // First deposit some tokens to establish initial reserves
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        // Set credit reserves
        treasury.setCreditReserves(100e18);
        treasury.setUnbackedSupply(200e18);

        // Calculate expected backing ratio
        uint256 totalReserves = treasury.totalReserves();
        uint256 totalSupply = app.totalSupply() - 200e18;
        uint256 expectedRatio = (totalReserves * 1e18) / totalSupply;

        // Verify backing ratio calculation
        assertEq(treasury.backingRatioE18(), expectedRatio);
    }

    function test_ExcessReservesWithCredit() public {
        // First deposit some tokens
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        // Set credit reserves
        treasury.setCreditReserves(100e18);

        // Calculate expected excess reserves
        uint256 totalReserves = treasury.totalReserves();
        uint256 totalSupply = treasury.totalSupply();
        uint256 expectedExcess = totalReserves > totalSupply ? totalReserves - totalSupply : 0;

        // Verify excess reserves calculation
        assertEq(treasury.excessReserves(), expectedExcess);
    }

    function test_UnbackedSupplyCustomCase1() public {
        app.mint(address(treasury), 500e18);
        mockQuoteToken.mint(address(treasury), 1000e18);
        treasury.syncReserves();

        assertEq(treasury.totalReserves(), 1000e18, "!totalReserves()");
        assertEq(treasury.totalSupply(), 500e18, "!totalSupply()");
        assertEq(treasury.actualReserves(), 1000e18, "!actualReserves()");
        assertEq(treasury.actualSupply(), 500e18, "!actualSupply()");
        assertEq(treasury.excessReserves(), 500e18, "!excessReserves()");
        assertEq(treasury.backingRatioE18(), 2e18, "!backingRatioE18()");

        // Set unbacked supply
        treasury.setUnbackedSupply(250e18);

        // Verify values are set correctly
        assertEq(treasury.unbackedSupply(), 250e18, "!unbackedSupply()");
        assertEq(treasury.totalReserves(), 1000e18, "!totalReserves() - 2");
        assertEq(treasury.totalSupply(), 250e18, "!totalSupply() - 2");
        assertEq(treasury.actualSupply(), 500e18, "!actualSupply() - 2");
        assertEq(treasury.excessReserves(), 750e18, "!excessReserves() - 2");
        assertEq(treasury.backingRatioE18(), 4e18, "!backingRatioE18() - 2");
    }

    function test_UnbackedSupplyCustomCase2() public {
        app.mint(address(treasury), 500e18);
        mockQuoteToken.mint(address(treasury), 1000e18);
        treasury.syncReserves();

        assertEq(treasury.totalReserves(), 1000e18, "!totalReserves()");
        assertEq(treasury.actualReserves(), 1000e18, "!actualReserves()");
        assertEq(treasury.totalSupply(), 500e18, "!totalSupply()");
        assertEq(treasury.actualSupply(), 500e18, "!actualSupply()");
        assertEq(treasury.excessReserves(), 500e18, "!excessReserves()");
        assertEq(treasury.backingRatioE18(), 2e18, "!backingRatioE18()");
        assertEq(treasury.calculateReserves(), treasury.totalReserves(), "!calculateReserves()");

        // Get projected epoch rate
        (uint256 aprBefore, uint256 epochRateBefore,,,) = rebaseController.projectedEpochRate();
        assertEq(aprBefore, 1250, "!aprBefore");
        assertGt(epochRateBefore, 5e18, "!epochRateBefore");

        // Set unbacked supply
        app.mint(address(treasury), 10000e18);
        treasury.setUnbackedSupply(10000e18);

        // Verify values are set correctly
        assertEq(treasury.totalReserves(), 1000e18, "!totalReserves()");
        assertEq(treasury.actualReserves(), 1000e18, "!actualReserves()");
        assertEq(treasury.totalSupply(), 500e18, "!totalSupply()");
        assertEq(treasury.actualSupply(), 10500e18, "!actualSupply()");
        assertEq(treasury.excessReserves(), 500e18, "!excessReserves()");
        assertEq(treasury.backingRatioE18(), 2e18, "!backingRatioE18()");

        // minting large amount of app and setting unbacked supply as the same should not change the apr
        (uint256 aprAfter, uint256 epochRateAfter,,,) = rebaseController.projectedEpochRate();
        assertEq(aprAfter, aprBefore, "!aprAfter");
        assertEq(epochRateAfter, epochRateBefore, "!epochRateAfter");
    }

    // todo this later
    // function test_RebaseWithCredit() public {
    //     // First deposit some tokens
    //     uint256 depositAmount = 1000e18;
    //     mockQuoteToken.mint(owner, depositAmount);
    //     mockQuoteToken.approve(address(treasury), depositAmount);
    //     treasury.deposit(depositAmount, address(mockQuoteToken), 0);

    //     // Set credit reserves
    //     treasury.setCreditReserves(100e18);
    //     treasury.setUnbackedSupply(200e18);

    //     // Fast forward to next epoch
    //     vm.warp(block.timestamp + rebaseController.EPOCH());

    //     // Execute rebase
    //     rebaseController.executeEpoch();

    //     // Verify backing ratio after rebase
    //     uint256 backingRatio = rebaseController.currentBackingRatio();
    //     assertTrue(backingRatio > 0, "Backing ratio should be positive after rebase");
    // }

    // function testFuzz_CreditDebitCalculations(
    //     uint256 creditReserves,
    //     uint256 debitReserves,
    //     uint256 creditSupply,
    //     uint256 debitSupply
    // ) public {
    //     // Bound the inputs to reasonable ranges
    //     creditReserves = bound(creditReserves, 0, 1000000e18);
    //     debitReserves = bound(debitReserves, 0, 1000000e18);
    //     creditSupply = bound(creditSupply, 0, 1000000e18);
    //     debitSupply = bound(debitSupply, 0, 1000000e18);

    //     // First deposit some tokens
    //     uint256 depositAmount = 1000e18;
    //     mockQuoteToken.mint(owner, depositAmount);
    //     mockQuoteToken.approve(address(treasury), depositAmount);
    //     treasury.deposit(depositAmount, address(mockQuoteToken), 0);

    //     // Set credit and debit values
    //     treasury.setCreditDebitReserves(creditReserves, debitReserves);
    //     treasury.setCreditDebitSupply(creditSupply, debitSupply);

    //     // Verify actual reserves calculation
    //     uint256 expectedActualReserves = treasury.totalReserves() - creditReserves + debitReserves;
    //     assertEq(treasury.actualReserves(), expectedActualReserves);

    //     // Verify actual supply calculation
    //     uint256 expectedActualSupply = app.totalSupply() - creditSupply + debitSupply;
    //     assertEq(treasury.actualSupply(), expectedActualSupply);

    //     // Verify backing ratio calculation
    //     uint256 expectedRatio = (expectedActualReserves * 1e18) / expectedActualSupply;
    //     assertEq(treasury.backingRatioE18(), expectedRatio);

    //     // Verify excess reserves calculation
    //     uint256 expectedExcess =
    //         expectedActualReserves > expectedActualSupply ? expectedActualReserves - expectedActualSupply : 0;
    //     assertEq(treasury.excessReserves(), expectedExcess);
    // }

    function test_ProjectedEpochRateWithCredit() public {
        // First deposit some tokens
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        // Set credit reserves
        treasury.setCreditReserves(100e18);
        // treasury.setUnbackedSupply(200e18);

        // Get projected epoch rate
        (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 toBurner) =
            rebaseController.projectedEpochRate();

        // Verify the calculations
        assertTrue(apr > 0, "APR should be positive");
        assertTrue(epochRate > 0, "Epoch rate should be positive");
        assertApproxEqAbs(toStakers + toOps + toBurner, epochRate, 1e18, "Distribution should sum to epoch rate");
    }

    function test_ManageWithCredit() public {
        // First deposit some tokens
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);
        treasury.syncReserves();

        assertEq(treasury.totalReserves(), depositAmount, "!totalReserves() - 0");
        assertEq(treasury.actualReserves(), depositAmount, "!actualReserves() - 0");
        assertEq(treasury.totalSupply(), app.totalSupply(), "!totalSupply() - 0");
        assertEq(treasury.actualSupply(), app.totalSupply(), "!actualSupply() - 0");
        assertEq(treasury.excessReserves(), 0, "!excessReserves() - 0");
        assertEq(treasury.backingRatioE18(), 1e18, "!backingRatioE18() - 0");

        // Set credit reserves
        treasury.setCreditReserves(100e18); // 100e18 credit
        // treasury.setUnbackedSupply(200e18); // 200e18 credit, 100e18 debit on app

        // Calculate excess reserves
        uint256 excess = treasury.excessReserves();

        assertEq(treasury.totalReserves(), depositAmount + 100e18, "!totalReserves()");
        assertEq(treasury.actualReserves(), depositAmount, "!actualReserves()");
        assertEq(treasury.totalSupply(), app.totalSupply(), "!totalSupply()");
        assertEq(treasury.actualSupply(), app.totalSupply(), "!actualSupply()");
        assertEq(treasury.excessReserves(), 100e18, "!excessReserves()");
        assertEq(treasury.backingRatioE18(), 1.1e18, "!backingRatioE18()");
        assertGt(treasury.excessReserves(), 0, "!excessReserves()");

        // Manage some tokens
        uint256 manageAmount = excess / 2;
        uint256 value = treasury.manage(address(mockQuoteToken), manageAmount);
        treasury.syncReserves();
        assertEq(value, manageAmount, "!value");

        // Verify reserves were updated correctly
        assertEq(treasury.totalReserves(), depositAmount - manageAmount + 100e18, "!totalReserves() - 2");
        assertEq(treasury.actualReserves(), depositAmount - manageAmount, "!actualReserves() - 2");
        assertEq(treasury.totalSupply(), app.totalSupply(), "!totalSupply() - 2");
        assertEq(treasury.actualSupply(), app.totalSupply(), "!actualSupply() - 2");
        assertEq(treasury.excessReserves(), 50e18, "!excessReserves() - 2");
        assertEq(treasury.backingRatioE18(), 1.05e18, "!backingRatioE18() - 2");
    }

    function test_MintWithUnbackedSupply() public {
        // First deposit some tokens
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        // Set credit reserves
        treasury.setUnbackedSupply(100e18);
        uint256 supplyBefore = app.totalSupply();

        // Mint some tokens
        uint256 mintAmount = 100e18 / 2;
        treasury.mint(user1, mintAmount);

        // Verify tokens were minted
        assertEq(app.balanceOf(user1), mintAmount, "!balanceOf()");

        // Verify actual supply was updated correctly
        uint256 expectedActualSupply = supplyBefore - 50e18;
        assertEq(treasury.totalSupply(), expectedActualSupply, "!totalSupply()");
    }
}
