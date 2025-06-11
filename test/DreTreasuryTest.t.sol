// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./BaseTest.sol";

contract AppTreasuryTest is BaseTest {
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

    function test_Initialize() public view {
        assertEq(address(treasury.app()), address(app));
        assertEq(treasury.totalReserves(), 0);
    }

    function test_EnableToken() public {
        // Enable a new token
        treasury.enable(address(mockQuoteToken));

        // Verify token is enabled
        assertTrue(treasury.enabledTokens(address(mockQuoteToken)));

        vm.stopPrank();
    }

    function test_DisableToken() public {
        // First enable the token
        treasury.enable(address(mockQuoteToken));

        // Then disable it
        treasury.disable(address(mockQuoteToken));

        // Verify token is disabled
        assertFalse(treasury.enabledTokens(address(mockQuoteToken)));

        vm.stopPrank();
    }

    function test_Deposit() public {
        // Enable token first
        treasury.enable(address(mockQuoteToken));

        // Mint some tokens to owner
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);

        // Approve treasury to spend tokens
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Deposit tokens
        uint256 profit = 100e18;
        uint256 dreMinted = treasury.deposit(depositAmount, address(mockQuoteToken), profit);

        // Verify App was minted correctly
        assertEq(app.balanceOf(owner), dreMinted, "App balance of owner should be equal to App minted");
        assertEq(dreMinted, depositAmount - profit, "App minted should be equal to deposit amount minus profit");

        // Verify reserves were updated
        assertEq(treasury.totalReserves(), depositAmount, "Total reserves should be equal to deposit amount");

        vm.stopPrank();
    }

    function test_Withdraw() public {
        // Enable token first
        treasury.enable(address(mockQuoteToken));

        // First deposit some tokens
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        uint256 profit = 100e18;
        treasury.deposit(depositAmount, address(mockQuoteToken), profit);

        assertEq(app.balanceOf(owner), 900e18);

        // Now withdraw
        uint256 withdrawAmount = 400e18;
        app.approve(address(treasury), type(uint256).max);
        treasury.withdraw(withdrawAmount, address(mockQuoteToken));

        // Verify App was burned
        assertEq(app.balanceOf(owner), 500e18);

        treasury.syncReserves();

        // Verify reserves were updated
        assertEq(treasury.totalReserves(), depositAmount - withdrawAmount);

        // Verify tokens were returned
        assertEq(mockQuoteToken.balanceOf(owner), withdrawAmount);

        vm.stopPrank();
    }

    function test_Manage() public {
        // Enable token first
        treasury.enable(address(mockQuoteToken));

        assertEq(treasury.actualSupply(), 0, "Actual supply should correctly reflect the initial state");

        // First deposit some tokens
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        uint256 profit = 100e18;
        treasury.deposit(depositAmount, address(mockQuoteToken), profit);

        treasury.syncReserves();

        assertEq(treasury.totalReserves(), 1000e18, "Total reserves should be equal to deposit amount");
        assertEq(treasury.actualReserves(), 1000e18, "Actual reserves should be equal to deposit amount");
        assertEq(treasury.actualSupply(), 900e18, "Actual supply should be equal to deposit amount");
        assertEq(treasury.excessReserves(), 100e18, "Excess reserves should be equal to profit");

        // Now manage some tokens
        uint256 manageAmount = 20e18;
        treasury.manage(address(mockQuoteToken), manageAmount);

        // Verify reserves were updated
        assertEq(treasury.totalReserves(), depositAmount - manageAmount);

        // Verify tokens were returned
        assertEq(mockQuoteToken.balanceOf(owner), manageAmount);

        vm.stopPrank();
    }

    function test_Mint() public {
        // Enable token first
        treasury.enable(address(mockQuoteToken));

        // First deposit some tokens
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        uint256 profit = 100e18;
        treasury.deposit(depositAmount, address(mockQuoteToken), profit);

        // Now mint some App
        uint256 mintAmount = 20e18;
        treasury.mint(user1, mintAmount);

        // Verify App was minted to user1
        assertEq(app.balanceOf(user1), mintAmount);

        vm.stopPrank();
    }

    function test_AuditReserves() public {
        // Enable token first
        treasury.enable(address(mockQuoteToken));

        // First deposit some tokens
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        uint256 profit = 100e18;
        treasury.deposit(depositAmount, address(mockQuoteToken), profit);

        // Audit reserves
        treasury.syncReserves();

        // Verify reserves were calculated correctly
        assertEq(treasury.totalReserves(), depositAmount);

        vm.stopPrank();
    }

    function test_BackingRatio() public {
        // Enable token first
        treasury.enable(address(mockQuoteToken));

        // First deposit some tokens
        uint256 depositAmount = 1000e18;
        mockQuoteToken.mint(owner, depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);
        uint256 profit = 100e18;
        treasury.deposit(depositAmount, address(mockQuoteToken), profit);

        // Calculate backing ratio
        uint256 backingRatio = treasury.backingRatioE18();

        // Verify backing ratio is correct (should be 1e18 since we deposited 1:1)
        assertEq(backingRatio, 1111111111111111111);

        vm.stopPrank();
    }

    function testFail_DepositInvalidToken() public {
        MockERC20 invalidToken = new MockERC20("Invalid Token", "INV");

        // Try to deposit without enabling token first
        uint256 depositAmount = 1000e18;
        invalidToken.mint(owner, depositAmount);
        invalidToken.approve(address(treasury), depositAmount);
        treasury.deposit(depositAmount, address(invalidToken), 0);

        vm.stopPrank();
    }

    function testFail_WithdrawInsufficientReserves() public {
        // Enable token first
        treasury.enable(address(mockQuoteToken));

        // Try to withdraw without having any reserves
        treasury.withdraw(1000e18, address(mockQuoteToken));

        vm.stopPrank();
    }

    function testFail_MintInsufficientReserves() public {
        // Try to mint without having any reserves
        treasury.mint(user1, 1000e18);

        vm.stopPrank();
    }
}
