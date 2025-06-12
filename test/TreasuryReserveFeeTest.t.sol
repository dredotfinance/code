// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./BaseTest.sol";

contract TreasuryReserveFeeTest is BaseTest {
    function setUp() public {
        setUpBaseTest();
        vm.startPrank(owner);

        // Setup authority roles
        dreAuthority.addReserveDepositor(owner);
        dreAuthority.addPolicy(owner);
        dreAuthority.addReserveManager(owner);
        dreAuthority.addReserveDepositor(owner);

        // Enable token for testing
        treasury.enable(address(mockQuoteToken));
    }

    function test_DepositWithReserveFee() public {
        // Setup initial amounts
        uint256 depositAmount = 1000e18;
        uint256 expectedFee = (depositAmount * 1000) / 10000; // 10% fee
        uint256 expectedDepositAfterFee = depositAmount - expectedFee;
        uint256 profit = 100e18;

        treasury.setReserveFee(1000);

        // Mint tokens to owner
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Get initial balances
        uint256 initialTreasuryBalance = mockQuoteToken.balanceOf(address(treasury));
        uint256 initialOperationsTreasuryBalance = mockQuoteToken.balanceOf(address(dreAuthority.operationsTreasury()));
        uint256 initialOwnerBalance = app.balanceOf(owner);

        // Perform deposit
        uint256 dreMinted = treasury.deposit(depositAmount, address(mockQuoteToken), profit);

        // Verify token transfers
        assertEq(
            mockQuoteToken.balanceOf(address(treasury)),
            initialTreasuryBalance + expectedDepositAfterFee,
            "Treasury should receive deposit amount minus fee"
        );
        assertEq(
            mockQuoteToken.balanceOf(address(dreAuthority.operationsTreasury())),
            initialOperationsTreasuryBalance + expectedFee,
            "Operations treasury should receive fee"
        );

        // Verify RZR minting
        assertEq(app.balanceOf(owner), initialOwnerBalance + dreMinted, "Owner should receive minted RZR tokens");
        assertEq(
            dreMinted,
            expectedDepositAfterFee - profit,
            "RZR minted should be equal to deposit amount minus fee and profit"
        );

        // Verify reserves
        assertEq(
            treasury.totalReserves(),
            expectedDepositAfterFee,
            "Total reserves should be equal to deposit amount minus fee"
        );

        vm.stopPrank();
    }

    function test_MultipleDepositsWithReserveFee() public {
        // First deposit
        uint256 firstDepositAmount = 1000e18;
        uint256 firstExpectedFee = (firstDepositAmount * 1000) / 10000;
        uint256 firstExpectedDepositAfterFee = firstDepositAmount - firstExpectedFee;
        uint256 firstProfit = 100e18;

        treasury.setReserveFee(1000);

        mockQuoteToken.mint(owner, firstDepositAmount);
        mockQuoteToken.approve(address(treasury), firstDepositAmount);
        treasury.deposit(firstDepositAmount, address(mockQuoteToken), firstProfit);

        // Second deposit
        uint256 secondDepositAmount = 2000e18;
        uint256 secondExpectedFee = (secondDepositAmount * 1000) / 10000;
        uint256 secondExpectedDepositAfterFee = secondDepositAmount - secondExpectedFee;
        uint256 secondProfit = 200e18;

        mockQuoteToken.mint(owner, secondDepositAmount);
        mockQuoteToken.approve(address(treasury), secondDepositAmount);
        treasury.deposit(secondDepositAmount, address(mockQuoteToken), secondProfit);

        // Verify total reserves
        assertEq(
            treasury.totalReserves(),
            firstExpectedDepositAfterFee + secondExpectedDepositAfterFee,
            "Total reserves should be sum of both deposits minus fees"
        );

        // Verify operations treasury received both fees
        assertEq(
            mockQuoteToken.balanceOf(address(dreAuthority.operationsTreasury())),
            firstExpectedFee + secondExpectedFee,
            "Operations treasury should receive sum of both fees"
        );

        vm.stopPrank();
    }

    function test_DepositWithZeroProfit() public {
        uint256 depositAmount = 1000e18;
        uint256 expectedFee = (depositAmount * 1000) / 10000;
        uint256 expectedDepositAfterFee = depositAmount - expectedFee;

        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        treasury.setReserveFee(1000);

        uint256 dreMinted = treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        // Verify RZR minting with zero profit
        assertEq(
            dreMinted,
            expectedDepositAfterFee,
            "RZR minted should be equal to deposit amount minus fee when profit is zero"
        );

        // Verify reserves
        assertEq(
            treasury.totalReserves(),
            expectedDepositAfterFee,
            "Total reserves should be equal to deposit amount minus fee"
        );

        vm.stopPrank();
    }
}
