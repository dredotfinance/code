// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/interfaces/IAppTreasury.sol";

contract AppTreasuryCapsDebtTest is BaseTest {
    event ReserveCapSet(address indexed token, uint256 cap);
    event ReserveDebtSet(address indexed token, uint256 debt);

    function setUp() public {
        setUpBaseTest();
        vm.startPrank(owner);

        authority.addReserveDepositor(owner);
        authority.addPolicy(owner);
        authority.addReserveManager(owner);
        authority.addReserveDepositor(owner);
    }

    // ========== RESERVE CAPS TESTS ==========

    function test_SetReserveCap() public {
        uint256 cap = 1000e18;
        treasury.setReserveCap(address(mockQuoteToken), cap);

        assertEq(treasury.reserveCaps(address(mockQuoteToken)), cap, "Reserve cap should be set correctly");
    }

    function test_SetReserveCapToZero() public {
        // First set a cap
        treasury.setReserveCap(address(mockQuoteToken), 1000e18);
        assertEq(treasury.reserveCaps(address(mockQuoteToken)), 1000e18, "Initial cap should be set");

        // Then set to zero (effectively removing the cap)
        treasury.setReserveCap(address(mockQuoteToken), 0);
        assertEq(treasury.reserveCaps(address(mockQuoteToken)), 0, "Reserve cap should be set to zero");
    }

    function test_SetReserveCapForMultipleTokens() public {
        // Enable additional tokens
        treasury.enable(address(mockQuoteToken2));
        treasury.enable(address(mockQuoteToken3));

        uint256 cap1 = 1000e18;
        uint256 cap2 = 2000e18;
        uint256 cap3 = 3000e18;

        treasury.setReserveCap(address(mockQuoteToken), cap1);
        treasury.setReserveCap(address(mockQuoteToken2), cap2);
        treasury.setReserveCap(address(mockQuoteToken3), cap3);

        assertEq(treasury.reserveCaps(address(mockQuoteToken)), cap1, "Cap for token 1 should be set correctly");
        assertEq(treasury.reserveCaps(address(mockQuoteToken2)), cap2, "Cap for token 2 should be set correctly");
        assertEq(treasury.reserveCaps(address(mockQuoteToken3)), cap3, "Cap for token 3 should be set correctly");
    }

    function test_DepositWithinCap() public {
        uint256 cap = 1000e18;
        treasury.setReserveCap(address(mockQuoteToken), cap);

        uint256 depositAmount = 500e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should succeed since deposit is within cap
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        assertEq(
            mockQuoteToken.balanceOf(address(treasury)), depositAmount, "Treasury should have received the deposit"
        );
    }

    function testFail_DepositExceedsCap() public {
        uint256 cap = 1000e18;
        treasury.setReserveCap(address(mockQuoteToken), cap);

        uint256 depositAmount = 1500e18; // Exceeds cap
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should fail since deposit exceeds cap
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);
    }

    function test_DepositAtCapLimit() public {
        uint256 cap = 1000e18;
        treasury.setReserveCap(address(mockQuoteToken), cap);

        uint256 depositAmount = 1000e18; // Exactly at cap
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should succeed since deposit is exactly at cap
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        assertEq(
            mockQuoteToken.balanceOf(address(treasury)), depositAmount, "Treasury should have received the deposit"
        );
    }

    function test_DepositWithNoCap() public {
        // No cap set (default is 0, which means no cap)
        uint256 depositAmount = 2000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should succeed since no cap is set
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        assertEq(
            mockQuoteToken.balanceOf(address(treasury)), depositAmount, "Treasury should have received the deposit"
        );
    }

    function test_MultipleDepositsWithinCap() public {
        uint256 cap = 1000e18;
        treasury.setReserveCap(address(mockQuoteToken), cap);

        // First deposit
        uint256 deposit1 = 400e18;
        mockQuoteToken.mint(owner, deposit1);
        mockQuoteToken.approve(address(treasury), deposit1);
        treasury.deposit(deposit1, address(mockQuoteToken), 0);

        // Second deposit
        uint256 deposit2 = 300e18;
        mockQuoteToken.mint(owner, deposit2);
        mockQuoteToken.approve(address(treasury), deposit2);
        treasury.deposit(deposit2, address(mockQuoteToken), 0);

        // Third deposit (should still be within cap)
        uint256 deposit3 = 200e18;
        mockQuoteToken.mint(owner, deposit3);
        mockQuoteToken.approve(address(treasury), deposit3);
        treasury.deposit(deposit3, address(mockQuoteToken), 0);

        uint256 totalDeposited = deposit1 + deposit2 + deposit3;
        assertEq(mockQuoteToken.balanceOf(address(treasury)), totalDeposited, "Total deposits should match");
        assertTrue(totalDeposited <= cap, "Total deposits should be within cap");
    }

    function testFail_MultipleDepositsExceedCap() public {
        uint256 cap = 1000e18;
        treasury.setReserveCap(address(mockQuoteToken), cap);

        // First deposit
        uint256 deposit1 = 400e18;
        mockQuoteToken.mint(owner, deposit1);
        mockQuoteToken.approve(address(treasury), deposit1);
        treasury.deposit(deposit1, address(mockQuoteToken), 0);

        // Second deposit
        uint256 deposit2 = 300e18;
        mockQuoteToken.mint(owner, deposit2);
        mockQuoteToken.approve(address(treasury), deposit2);
        treasury.deposit(deposit2, address(mockQuoteToken), 0);

        // Third deposit (should exceed cap)
        uint256 deposit3 = 400e18; // This will make total 1100e18 > 1000e18 cap
        mockQuoteToken.mint(owner, deposit3);
        mockQuoteToken.approve(address(treasury), deposit3);
        treasury.deposit(deposit3, address(mockQuoteToken), 0);
    }

    // ========== RESERVE DEBT TESTS ==========

    function test_SetReserveDebt() public {
        uint256 debt = 1000e18;
        treasury.setReserveDebt(address(mockQuoteToken), debt);

        assertEq(treasury.reserveDebts(address(mockQuoteToken)), debt, "Reserve debt should be set correctly");
    }

    function test_SetReserveDebtToZero() public {
        // First set a debt
        treasury.setReserveDebt(address(mockQuoteToken), 1000e18);
        assertEq(treasury.reserveDebts(address(mockQuoteToken)), 1000e18, "Initial debt should be set");

        // Then set to zero (effectively removing the debt limit)
        treasury.setReserveDebt(address(mockQuoteToken), 0);
        assertEq(treasury.reserveDebts(address(mockQuoteToken)), 0, "Reserve debt should be set to zero");
    }

    function test_SetReserveDebtForMultipleTokens() public {
        // Enable additional tokens
        treasury.enable(address(mockQuoteToken2));
        treasury.enable(address(mockQuoteToken3));

        uint256 debt1 = 1000e18;
        uint256 debt2 = 2000e18;
        uint256 debt3 = 3000e18;

        treasury.setReserveDebt(address(mockQuoteToken), debt1);
        treasury.setReserveDebt(address(mockQuoteToken2), debt2);
        treasury.setReserveDebt(address(mockQuoteToken3), debt3);

        assertEq(treasury.reserveDebts(address(mockQuoteToken)), debt1, "Debt for token 1 should be set correctly");
        assertEq(treasury.reserveDebts(address(mockQuoteToken2)), debt2, "Debt for token 2 should be set correctly");
        assertEq(treasury.reserveDebts(address(mockQuoteToken3)), debt3, "Debt for token 3 should be set correctly");
    }

    function test_DepositWithinDebtLimit() public {
        uint256 debt = 1000e18;
        treasury.setReserveDebt(address(mockQuoteToken), debt);

        uint256 depositAmount = 500e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should succeed since deposit value is within debt limit
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        assertEq(
            mockQuoteToken.balanceOf(address(treasury)), depositAmount, "Treasury should have received the deposit"
        );
    }

    function testFail_DepositExceedsDebtLimit() public {
        uint256 debt = 1000e18;
        treasury.setReserveDebt(address(mockQuoteToken), debt);

        uint256 depositAmount = 1500e18; // Value will be 1500e18 (1:1 price) which exceeds debt limit
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should fail since deposit value exceeds debt limit
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);
    }

    function test_DepositAtDebtLimit() public {
        uint256 debt = 1000e18;
        treasury.setReserveDebt(address(mockQuoteToken), debt);

        uint256 depositAmount = 1000e18; // Exactly at debt limit
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should succeed since deposit value is exactly at debt limit
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        assertEq(
            mockQuoteToken.balanceOf(address(treasury)), depositAmount, "Treasury should have received the deposit"
        );
    }

    function test_DepositWithNoDebtLimit() public {
        // No debt limit set (default is 0, which means no debt limit)
        uint256 depositAmount = 2000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should succeed since no debt limit is set
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        assertEq(
            mockQuoteToken.balanceOf(address(treasury)), depositAmount, "Treasury should have received the deposit"
        );
    }

    function test_DepositWithDifferentTokenPrices() public {
        // Enable token with different price (2:1 ratio)
        treasury.enable(address(mockQuoteToken2));

        uint256 debt = 1000e18;
        treasury.setReserveDebt(address(mockQuoteToken2), debt);

        // With 2:1 price, 500e18 tokens = 1000e18 value (at debt limit)
        uint256 depositAmount = 500e18;
        mockQuoteToken2.mint(owner, depositAmount);
        mockQuoteToken2.approve(address(treasury), depositAmount);

        // Should succeed since deposit value is exactly at debt limit
        treasury.deposit(depositAmount, address(mockQuoteToken2), 0);

        assertEq(
            mockQuoteToken2.balanceOf(address(treasury)), depositAmount, "Treasury should have received the deposit"
        );
    }

    function testFail_DepositWithDifferentTokenPricesExceedsDebt() public {
        // Enable token with different price (2:1 ratio)
        treasury.enable(address(mockQuoteToken2));

        uint256 debt = 1000e18;
        treasury.setReserveDebt(address(mockQuoteToken2), debt);

        // With 2:1 price, 600e18 tokens = 1200e18 value (exceeds debt limit)
        uint256 depositAmount = 600e18;
        mockQuoteToken2.mint(owner, depositAmount);
        mockQuoteToken2.approve(address(treasury), depositAmount);

        // Should fail since deposit value exceeds debt limit
        treasury.deposit(depositAmount, address(mockQuoteToken2), 0);
    }

    // ========== COMBINED CAPS AND DEBT TESTS ==========

    function test_DepositWithBothCapAndDebt() public {
        uint256 cap = 1000e18;
        uint256 debt = 800e18;

        treasury.setReserveCap(address(mockQuoteToken), cap);
        treasury.setReserveDebt(address(mockQuoteToken), debt);

        uint256 depositAmount = 600e18; // Within both cap and debt limits
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should succeed since deposit is within both limits
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        assertEq(
            mockQuoteToken.balanceOf(address(treasury)), depositAmount, "Treasury should have received the deposit"
        );
    }

    function testFail_DepositExceedsCapButWithinDebt() public {
        uint256 cap = 500e18;
        uint256 debt = 1000e18;

        treasury.setReserveCap(address(mockQuoteToken), cap);
        treasury.setReserveDebt(address(mockQuoteToken), debt);

        uint256 depositAmount = 600e18; // Exceeds cap but within debt
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should fail since deposit exceeds cap
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);
    }

    function testFail_DepositWithinCapButExceedsDebt() public {
        uint256 cap = 1000e18;
        uint256 debt = 500e18;

        treasury.setReserveCap(address(mockQuoteToken), cap);
        treasury.setReserveDebt(address(mockQuoteToken), debt);

        uint256 depositAmount = 600e18; // Within cap but exceeds debt
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should fail since deposit exceeds debt
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);
    }

    function testFail_DepositExceedsBothCapAndDebt() public {
        uint256 cap = 500e18;
        uint256 debt = 400e18;

        treasury.setReserveCap(address(mockQuoteToken), cap);
        treasury.setReserveDebt(address(mockQuoteToken), debt);

        uint256 depositAmount = 600e18; // Exceeds both cap and debt
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Should fail since deposit exceeds both limits
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);
    }

    // ========== ACCESS CONTROL TESTS ==========

    function testFail_SetReserveCapNotPolicy() public {
        vm.stopPrank();
        vm.startPrank(user1);

        treasury.setReserveCap(address(mockQuoteToken), 1000e18);
    }

    function testFail_SetReserveDebtNotPolicy() public {
        vm.stopPrank();
        vm.startPrank(user1);

        treasury.setReserveDebt(address(mockQuoteToken), 1000e18);
    }

    // ========== EDGE CASES ==========

    function test_SetReserveCapForDisabledToken() public {
        // Set cap for a token that's not enabled
        address disabledToken = address(0x123);
        uint256 cap = 1000e18;

        treasury.setReserveCap(disabledToken, cap);
        assertEq(treasury.reserveCaps(disabledToken), cap, "Cap should be set even for disabled token");
    }

    function test_SetReserveDebtForDisabledToken() public {
        // Set debt for a token that's not enabled
        address disabledToken = address(0x123);
        uint256 debt = 1000e18;

        treasury.setReserveDebt(disabledToken, debt);
        assertEq(treasury.reserveDebts(disabledToken), debt, "Debt should be set even for disabled token");
    }

    function test_UpdateCapAfterDeposit() public {
        // Initial deposit without cap
        uint256 initialDeposit = 500e18;
        mockQuoteToken.mint(owner, initialDeposit);
        mockQuoteToken.approve(address(treasury), initialDeposit);
        treasury.deposit(initialDeposit, address(mockQuoteToken), 0);

        // Set cap lower than current balance
        uint256 newCap = 300e18;
        treasury.setReserveCap(address(mockQuoteToken), newCap);

        // Try to deposit more (should fail)
        uint256 additionalDeposit = 200e18;
        mockQuoteToken.mint(owner, additionalDeposit);
        mockQuoteToken.approve(address(treasury), additionalDeposit);

        vm.expectRevert("Treasury: reserve cap exceeded");
        treasury.deposit(additionalDeposit, address(mockQuoteToken), 0);
    }

    function test_UpdateDebtAfterDeposit() public {
        // Initial deposit without debt limit
        uint256 initialDeposit = 500e18;
        mockQuoteToken.mint(owner, initialDeposit);
        mockQuoteToken.approve(address(treasury), initialDeposit);
        treasury.deposit(initialDeposit, address(mockQuoteToken), 0);

        // Set debt limit lower than current value
        uint256 newDebt = 300e18;
        treasury.setReserveDebt(address(mockQuoteToken), newDebt);

        // Try to deposit more (should fail)
        uint256 additionalDeposit = 200e18;
        mockQuoteToken.mint(owner, additionalDeposit);
        mockQuoteToken.approve(address(treasury), additionalDeposit);

        vm.expectRevert("Treasury: reserve debt exceeded");
        treasury.deposit(additionalDeposit, address(mockQuoteToken), 0);
    }

    // ========== EVENTS TESTS ==========

    function test_ReserveCapSetEvent() public {
        uint256 cap = 1000e18;

        vm.expectEmit(true, false, false, true);
        emit ReserveCapSet(address(mockQuoteToken), cap);

        treasury.setReserveCap(address(mockQuoteToken), cap);
    }

    function test_ReserveDebtSetEvent() public {
        uint256 debt = 1000e18;

        vm.expectEmit(true, false, false, true);
        emit ReserveDebtSet(address(mockQuoteToken), debt);

        treasury.setReserveDebt(address(mockQuoteToken), debt);
    }

    function test_ReserveCapSetEventWithZero() public {
        // First set a cap
        treasury.setReserveCap(address(mockQuoteToken), 1000e18);

        // Then set to zero
        vm.expectEmit(true, false, false, true);
        emit ReserveCapSet(address(mockQuoteToken), 0);

        treasury.setReserveCap(address(mockQuoteToken), 0);
    }

    function test_ReserveDebtSetEventWithZero() public {
        // First set a debt
        treasury.setReserveDebt(address(mockQuoteToken), 1000e18);

        // Then set to zero
        vm.expectEmit(true, false, false, true);
        emit ReserveDebtSet(address(mockQuoteToken), 0);

        treasury.setReserveDebt(address(mockQuoteToken), 0);
    }
}
