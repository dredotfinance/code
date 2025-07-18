// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";

contract AppBondDepositoryTest is BaseTest {
    uint256 public constant BOND_AMOUNT = 1000e18;
    uint256 public constant INITIAL_PRICE = 1.1e18; // 1.1 RZR per quote token
    uint256 public constant FINAL_PRICE = 0.9e18; // 0.9 RZR per quote token
    uint256 public constant BOND_DURATION = 7 days;

    uint256 public constant VESTING_PERIOD = 12 days;
    uint256 public constant STAKING_LOCK_PERIOD = 30 days;

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);
        authority.addPolicy(owner);

        // Enable mock quote token in treasury
        treasury.enable(address(mockQuoteToken));

        vm.stopPrank();
    }

    function test_Initialize() public view {
        assertEq(address(bondDepository.app()), address(app));
        assertEq(address(bondDepository.staking()), address(staking));
        assertEq(address(bondDepository.treasury()), address(treasury));
        assertEq(bondDepository.bondLength(), 0);
    }

    function test_CreateBond() public {
        vm.startPrank(owner);

        uint256 bondId = bondDepository.create(
            mockQuoteToken, BOND_AMOUNT, INITIAL_PRICE, FINAL_PRICE, 0, BOND_DURATION, 1 days, 1 days, false
        );

        // Verify bond details
        IAppBondDepository.Bond memory bond = bondDepository.getBond(bondId);

        assertEq(bond.capacity, BOND_AMOUNT);
        assertEq(address(bond.quoteToken), address(mockQuoteToken));
        assertEq(bond.totalDebt, 0);
        assertEq(bond.maxPayout, BOND_AMOUNT);
        assertEq(bond.sold, 0);
        assertEq(bond.purchased, 0);
        assertEq(bond.initialPrice, INITIAL_PRICE);
        assertEq(bond.finalPrice, FINAL_PRICE);
        assertEq(bond.endTime, bond.startTime + BOND_DURATION);

        vm.stopPrank();
    }

    function test_Deposit() public {
        vm.startPrank(owner);

        // Create bond
        uint256 bondId = bondDepository.create(
            mockQuoteToken, BOND_AMOUNT, INITIAL_PRICE, FINAL_PRICE, 0, BOND_DURATION, 1 days, 1 days, false
        );

        vm.stopPrank();

        // Switch to depositor
        vm.startPrank(user1);

        // Mint quote tokens to user
        mockQuoteToken.mint(user1, BOND_AMOUNT);
        mockQuoteToken.approve(address(bondDepository), BOND_AMOUNT);

        // Deposit to bond
        (uint256 payout, uint256 tokenId) = bondDepository.deposit(bondId, BOND_AMOUNT, INITIAL_PRICE, 0, user1);

        // Verify bond position
        IAppBondDepository.BondPosition memory position = bondDepository.positions(tokenId);

        assertEq(position.bondId, bondId);
        assertEq(position.amount, payout);
        assertEq(position.quoteAmount, BOND_AMOUNT);
        assertEq(position.claimedAmount, 0);
        assertFalse(position.isStaked);

        // Verify bond state
        IAppBondDepository.Bond memory bond = bondDepository.getBond(bondId);

        assertApproxEqRel(bond.capacity, 9.09e19, 1e18); // Bond is partially sold
        assertEq(bond.sold, payout);
        assertEq(bond.purchased, BOND_AMOUNT);

        vm.stopPrank();
    }

    function test_Claim() public {
        vm.startPrank(owner);

        // Create bond
        uint256 bondId = bondDepository.create(
            mockQuoteToken, BOND_AMOUNT, INITIAL_PRICE, FINAL_PRICE, 0, BOND_DURATION, 1 days, 1 days, false
        );

        vm.stopPrank();

        // Switch to depositor
        vm.startPrank(user1);

        // Deposit to bond
        mockQuoteToken.mint(user1, BOND_AMOUNT);
        mockQuoteToken.approve(address(bondDepository), BOND_AMOUNT);
        (uint256 payout, uint256 tokenId) = bondDepository.deposit(bondId, BOND_AMOUNT, INITIAL_PRICE, 0, user1);

        // Fast forward past vesting period
        vm.warp(block.timestamp + bondDepository.bonds(bondId).vestingPeriod + 1);

        // Claim tokens
        uint256 balanceBefore = app.balanceOf(user1);
        bondDepository.claim(tokenId);

        // Verify tokens received
        assertEq(app.balanceOf(user1), balanceBefore + payout);

        vm.stopPrank();
    }

    function test_Stake() public {
        vm.startPrank(owner);

        // Create bond
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            BOND_AMOUNT,
            INITIAL_PRICE,
            FINAL_PRICE,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );

        vm.stopPrank();

        // Switch to depositor
        vm.startPrank(user1);

        // Deposit to bond
        mockQuoteToken.mint(user1, BOND_AMOUNT);
        mockQuoteToken.approve(address(bondDepository), BOND_AMOUNT);
        (uint256 payout, uint256 tokenId) = bondDepository.deposit(bondId, BOND_AMOUNT, INITIAL_PRICE, 0, user1);

        // Fast forward past vesting period
        vm.warp(block.timestamp + bondDepository.bonds(bondId).vestingPeriod + 1);

        // Stake tokens
        bondDepository.stake(tokenId, payout);

        // Verify position is staked
        IAppBondDepository.BondPosition memory position = bondDepository.positions(tokenId);

        assertTrue(position.isStaked);

        vm.stopPrank();
    }

    function test_CurrentPrice() public {
        vm.startPrank(owner);

        // Create bond
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            BOND_AMOUNT,
            INITIAL_PRICE,
            FINAL_PRICE,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );

        // Check initial price
        assertEq(bondDepository.currentPrice(bondId), INITIAL_PRICE);

        // Fast forward half way
        vm.warp(block.timestamp + BOND_DURATION / 2);

        // Check middle price
        uint256 expectedPrice = INITIAL_PRICE - ((INITIAL_PRICE - FINAL_PRICE) / 2);
        assertEq(bondDepository.currentPrice(bondId), expectedPrice);

        // Fast forward to end
        vm.warp(block.timestamp + BOND_DURATION);

        // Check final price
        assertEq(bondDepository.currentPrice(bondId), FINAL_PRICE);

        vm.stopPrank();
    }

    function testFail_CreateBondInvalidPrice() public {
        vm.startPrank(owner);

        // Try to create bond with invalid price range
        bondDepository.create(
            mockQuoteToken,
            BOND_AMOUNT,
            FINAL_PRICE, // Initial price lower than final price
            INITIAL_PRICE,
            0, // min price
            BOND_DURATION,
            1 days,
            1 days,
            false
        );

        vm.stopPrank();
    }

    function testFail_CreateBondInvalidDuration() public {
        vm.startPrank(owner);

        // Try to create bond with zero duration
        bondDepository.create(
            mockQuoteToken, BOND_AMOUNT, INITIAL_PRICE, FINAL_PRICE, 0, 0, VESTING_PERIOD, STAKING_LOCK_PERIOD, false
        );

        vm.stopPrank();
    }

    function testFail_DepositAfterEnd() public {
        vm.startPrank(owner);

        // Create bond
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            BOND_AMOUNT,
            INITIAL_PRICE,
            FINAL_PRICE,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );

        // Fast forward past end time
        vm.warp(block.timestamp + BOND_DURATION + 1);

        vm.stopPrank();

        // Try to deposit
        vm.startPrank(user1);
        mockQuoteToken.mint(user1, BOND_AMOUNT);
        mockQuoteToken.approve(address(bondDepository), BOND_AMOUNT);
        bondDepository.deposit(bondId, BOND_AMOUNT, INITIAL_PRICE, 0, user1);

        vm.stopPrank();
    }

    function testFail_DepositExceedsCapacity() public {
        vm.startPrank(owner);

        // Create bond with small capacity
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            BOND_AMOUNT / 2, // Half capacity
            INITIAL_PRICE,
            FINAL_PRICE,
            0, // min price
            BOND_DURATION,
            1 days,
            1 days,
            false
        );

        vm.stopPrank();

        // Try to deposit more than capacity
        vm.startPrank(user1);
        mockQuoteToken.mint(user1, BOND_AMOUNT);
        mockQuoteToken.approve(address(bondDepository), BOND_AMOUNT);
        bondDepository.deposit(bondId, BOND_AMOUNT, INITIAL_PRICE, 0, user1);

        vm.stopPrank();
    }

    function testFail_ClaimBeforeVesting() public {
        vm.startPrank(owner);

        // Create bond
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            BOND_AMOUNT,
            INITIAL_PRICE,
            FINAL_PRICE,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );

        vm.stopPrank();

        // Switch to depositor
        vm.startPrank(user1);

        // Deposit to bond
        mockQuoteToken.mint(user1, BOND_AMOUNT);
        mockQuoteToken.approve(address(bondDepository), BOND_AMOUNT);
        bondDepository.deposit(bondId, BOND_AMOUNT, INITIAL_PRICE, 0, user1);

        // Try to claim before vesting
        bondDepository.claim(1); // tokenId will be 1 since it's the first deposit

        vm.stopPrank();
    }

    function test_StakeBeforeVesting() public {
        vm.startPrank(owner);

        // Create bond
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            BOND_AMOUNT,
            INITIAL_PRICE,
            FINAL_PRICE,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );

        vm.stopPrank();

        // Switch to depositor
        vm.startPrank(user1);

        // Deposit to bond
        mockQuoteToken.mint(user1, BOND_AMOUNT);
        mockQuoteToken.approve(address(bondDepository), BOND_AMOUNT);
        (uint256 payout, uint256 tokenId) = bondDepository.deposit(bondId, BOND_AMOUNT, INITIAL_PRICE, 0, user1);

        // Try to stake before vesting; it should work
        bondDepository.stake(tokenId, payout);

        vm.stopPrank();
    }

    function testFail_StakeAlreadyStaked() public {
        vm.startPrank(owner);

        // Create bond
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            BOND_AMOUNT,
            INITIAL_PRICE,
            FINAL_PRICE,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );

        vm.stopPrank();

        // Switch to depositor
        vm.startPrank(user1);

        // Deposit to bond
        mockQuoteToken.mint(user1, BOND_AMOUNT);
        mockQuoteToken.approve(address(bondDepository), BOND_AMOUNT);
        (uint256 payout, uint256 tokenId) = bondDepository.deposit(bondId, BOND_AMOUNT, INITIAL_PRICE, 0, user1);

        // Fast forward past vesting period
        vm.warp(block.timestamp + bondDepository.bonds(bondId).vestingPeriod + 1);

        // Stake tokens
        bondDepository.stake(tokenId, payout);

        // Try to stake again
        bondDepository.stake(tokenId, payout);

        vm.stopPrank();
    }

    function testFuzz_BondSales(uint256 bondAmount, uint256 initialPrice, uint256 finalPrice, uint256 depositAmount)
        public
    {
        // Bound the inputs to reasonable ranges
        bondAmount = bound(bondAmount, 1e18, 1000000e18);
        initialPrice = bound(initialPrice, 1e18, 2e18); // 1-2 RZR per quote token
        finalPrice = bound(finalPrice, 0.5e18, initialPrice); // Final price must be lower than initial
        depositAmount = bound(depositAmount, 1e18, bondAmount);

        vm.assume(initialPrice > finalPrice);

        vm.startPrank(owner);

        // Create bond
        uint256 capacity = bondAmount * initialPrice / 1e18;
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            capacity,
            initialPrice,
            finalPrice,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );

        // Verify bond details
        IAppBondDepository.Bond memory bond = bondDepository.getBond(bondId);
        assertEq(bond.capacity, capacity);
        assertEq(bond.initialPrice, initialPrice);
        assertEq(bond.finalPrice, finalPrice);
        assertEq(bond.endTime, bond.startTime + BOND_DURATION);

        vm.stopPrank();

        // Switch to depositor
        vm.startPrank(user1);

        // Mint quote tokens to user
        mockQuoteToken.mint(user1, depositAmount);
        mockQuoteToken.approve(address(bondDepository), depositAmount);

        // Calculate expected payout based on current price
        uint256 currentPrice = bondDepository.currentPrice(bondId);
        uint256 expectedPayout = (depositAmount * 1e18) / currentPrice;

        // Deposit to bond
        (uint256 payout, uint256 tokenId) = bondDepository.deposit(bondId, depositAmount, currentPrice, 0, user1);

        // Verify payout is within acceptable range (allowing for small rounding differences)
        assertApproxEqRel(payout, expectedPayout, 0.0001e18, "Payout amount incorrect");

        // Verify bond state
        bond = bondDepository.getBond(bondId);
        assertEq(bond.sold, payout);
        assertEq(bond.purchased, depositAmount);

        // Verify position details
        IAppBondDepository.BondPosition memory position = bondDepository.positions(tokenId);

        assertEq(position.bondId, bondId);
        assertEq(position.amount, payout);
        assertEq(position.quoteAmount, depositAmount);
        assertEq(position.claimedAmount, 0);
        assertFalse(position.isStaked);

        vm.stopPrank();
    }

    function testFuzz_BondPriceDecay(uint256 bondAmount, uint256 initialPrice, uint256 finalPrice, uint256 timeElapsed)
        public
    {
        // Bound the inputs to reasonable ranges
        bondAmount = bound(bondAmount, 1e18, 1000000e18);
        initialPrice = bound(initialPrice, 1e18, 2e18);
        finalPrice = bound(finalPrice, 0.5e18, initialPrice);
        timeElapsed = bound(timeElapsed, 0, BOND_DURATION);

        vm.assume(initialPrice > finalPrice);
        vm.startPrank(owner);

        // Create bond
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            bondAmount,
            initialPrice,
            finalPrice,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );

        // Fast forward by random time
        vm.warp(block.timestamp + timeElapsed);

        // Calculate expected price
        uint256 expectedPrice;
        if (timeElapsed >= BOND_DURATION) {
            expectedPrice = finalPrice;
        } else {
            uint256 priceRange = initialPrice - finalPrice;
            uint256 priceDecay = (priceRange * timeElapsed) / BOND_DURATION;
            expectedPrice = initialPrice - priceDecay;
        }

        // Verify current price
        uint256 currentPrice = bondDepository.currentPrice(bondId);
        assertApproxEqRel(currentPrice, expectedPrice, 0.0001e18, "Price decay incorrect");

        vm.stopPrank();
    }

    function testFuzz_BondCapacity(
        uint256 bondAmount,
        uint256 initialPrice,
        uint256 finalPrice,
        uint256[] memory depositAmounts
    ) public {
        // Bound the inputs to reasonable ranges
        bondAmount = bound(bondAmount, 1e18, 1000000e18);
        initialPrice = bound(initialPrice, 1e18, 2e18);
        finalPrice = bound(finalPrice, 1e10, initialPrice - 1);
        vm.assume(initialPrice >= finalPrice);
        vm.assume(depositAmounts.length > 1);

        // Limit array size and bound deposit amounts
        uint256 numDeposits = bound(depositAmounts.length, 1, 10);
        for (uint256 i = 0; i < numDeposits; i++) {
            depositAmounts[i] = bound(depositAmounts[i], 1e16, bondAmount / numDeposits);
        }

        vm.startPrank(owner);

        // Create bond
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            bondAmount,
            initialPrice,
            finalPrice,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );

        vm.stopPrank();

        // Switch to depositor
        vm.startPrank(user1);

        uint256 totalDeposited;
        uint256 totalPayout;

        // Make multiple deposits
        for (uint256 i = 0; i < numDeposits; i++) {
            uint256 depositAmount = depositAmounts[i];

            // Skip if this deposit would exceed capacity
            if (totalDeposited + depositAmount > bondAmount) {
                continue;
            }

            // Mint quote tokens to user
            mockQuoteToken.mint(user1, depositAmount);
            mockQuoteToken.approve(address(bondDepository), depositAmount);

            // Get current price
            uint256 currentPrice = bondDepository.currentPrice(bondId);
            uint256 expectedPayout = (depositAmount * 1e18) / currentPrice;

            // Deposit to bond
            (uint256 payout,) = bondDepository.deposit(bondId, depositAmount, currentPrice, 0, user1);

            // Verify payout is within acceptable range
            assertApproxEqRel(payout, expectedPayout, 0.0001e18, "Payout amount incorrect");

            totalDeposited += depositAmount;
            totalPayout += payout;
        }

        // Verify final bond state
        IAppBondDepository.Bond memory bond = bondDepository.getBond(bondId);
        assertEq(bond.sold, totalPayout);
        assertEq(bond.purchased, totalDeposited);
        assertTrue(bond.purchased <= bondAmount, "Bond capacity exceeded");

        vm.stopPrank();
    }

    function test_TreasuryInflationWithOraclePriceMovements() public {
        vm.startPrank(owner);
        authority.addPolicy(owner);

        // Enable multiple quote tokens in treasury with different initial prices
        treasury.enable(address(mockQuoteToken));
        treasury.enable(address(mockQuoteToken2));
        treasury.enable(address(mockQuoteToken3));

        treasury.setReserveDebt(address(mockQuoteToken), 100000000e18);
        treasury.setReserveDebt(address(mockQuoteToken2), 100000000e18);
        treasury.setReserveDebt(address(mockQuoteToken3), 100000000e18);

        // Set initial oracle prices
        mockOracle.setPrice(1e18); // 1:1 price
        mockOracle2.setPrice(2e18); // 2:1 price
        mockOracle3.setPrice(0.5e18); // 0.5:1 price

        // Mint initial reserves to treasury
        uint256 initialReserve1 = 1000e18;
        uint256 initialReserve2 = 500e18;
        uint256 initialReserve3 = 2000e18;

        mockQuoteToken.mint(address(treasury), initialReserve1);
        mockQuoteToken2.mint(address(treasury), initialReserve2);
        mockQuoteToken3.mint(address(treasury), initialReserve3);
        treasury.syncReserves();

        // Calculate initial treasury value
        uint256 initialValue = treasury.totalReserves();
        uint256 expectedInitialValue = (
            (initialReserve1 * 1e18) // 1000 * 1 = 1000
                + (initialReserve2 * 2e18) // 500 * 2 = 1000
                + (initialReserve3 * 0.5e18)
        ) / 1e18; // 2000 * 0.5 = 1000
        assertApproxEqRel(initialValue, expectedInitialValue, 0.0001e18, "Initial treasury value incorrect");

        // Simulate price increases
        mockOracle.setPrice(1.5e18); // 50% increase
        mockOracle2.setPrice(3e18); // 50% increase
        mockOracle3.setPrice(0.75e18); // 50% increase
        treasury.syncReserves();

        // Calculate new treasury value
        uint256 newValue = treasury.totalReserves();
        uint256 expectedNewValue = (initialReserve1 * 1.5e18) // 1000 * 1.5 = 1500
            + (initialReserve2 * 3e18) // 500 * 3 = 1500
            + (initialReserve3 * 0.75e18); // 2000 * 0.75 = 1500
        assertApproxEqRel(newValue, expectedNewValue / 1e18, 0.0001e18, "New treasury value incorrect");

        // Verify inflation rate
        uint256 inflationRate = (newValue * 1e18) / initialValue;
        assertApproxEqRel(inflationRate, 1.5e18, 0.0001e18, "Inflation rate incorrect");

        // Simulate price decreases
        mockOracle.setPrice(0.75e18); // 50% decrease from initial
        mockOracle2.setPrice(1.5e18); // 25% decrease from initial
        mockOracle3.setPrice(0.25e18); // 50% decrease from initial

        treasury.syncReserves();

        // Calculate final treasury value
        uint256 finalValue = treasury.totalReserves();
        uint256 expectedFinalValue = (initialReserve1 * 0.75e18) // 1000 * 0.75 = 750
            + (initialReserve2 * 1.5e18) // 500 * 1.5 = 750
            + (initialReserve3 * 0.25e18); // 2000 * 0.25 = 500
        assertApproxEqRel(finalValue, expectedFinalValue / 1e18, 0.0001e18, "Final treasury value incorrect");

        // Verify deflation rate
        uint256 deflationRate = (finalValue * 1e18) / initialValue;
        assertApproxEqRel(deflationRate, 0.666666e18, 0.0001e18, "Deflation rate incorrect");

        // Test bond creation with new prices
        uint256 bondAmount = 1000e18;
        uint256 initialPrice = 1.1e18;
        uint256 finalPrice = 0.9e18;

        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            bondAmount,
            initialPrice,
            finalPrice,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );

        // Verify bond price calculations consider new oracle prices
        uint256 currentPrice = bondDepository.currentPrice(bondId);
        assertApproxEqRel(currentPrice, initialPrice, 0.0001e18, "Bond price incorrect");

        // Test deposit with new prices
        vm.stopPrank();
        vm.startPrank(user1);

        uint256 depositAmount = 100e18;
        mockQuoteToken.mint(user1, depositAmount);
        mockQuoteToken.approve(address(bondDepository), depositAmount);

        (uint256 payout,) = bondDepository.deposit(bondId, depositAmount, currentPrice, 0, user1);

        // Verify payout considers new oracle prices
        uint256 expectedPayout = (depositAmount * 1e18) / currentPrice;
        assertApproxEqRel(payout, expectedPayout, 0.0001e18, "Payout amount incorrect");

        vm.stopPrank();
    }

    function test_USDCBondWithDiscount() public {
        vm.startPrank(owner);

        // Setup USDC mock token with 6 decimals
        MockERC20 usdc = new MockERC20("USD Coin", "USDC");
        usdc.setDecimals(6);

        MockOracle usdcOracle = new MockOracle(1e18);
        appOracle.updateOracle(address(usdc), address(usdcOracle));
        treasury.enable(address(usdc));

        // Calculate bond parameters
        // uint256 dreAmount = 10000e18; // 10000 RZR
        uint256 initialPrice = 2e6; // 1 RZR = 1 USDC
        uint256 finalPrice = 1.9e6; // 10% discount (0.9 * 1 = 0.9 USDC)
        uint256 duration = 7 days;

        // Calculate RZR capacity (15000 RZR for 10000 RZR at $1.50)
        uint256 dreCapacity = 15000e18; // 15000 RZR (6 decimals)

        // Create bond
        uint256 bondId = bondDepository.create(
            usdc, dreCapacity, initialPrice, finalPrice, 0, duration, VESTING_PERIOD, STAKING_LOCK_PERIOD, false
        );

        // Verify bond details
        IAppBondDepository.Bond memory bond = bondDepository.getBond(bondId);
        assertEq(bond.capacity, dreCapacity);
        assertEq(address(bond.quoteToken), address(usdc));
        assertEq(bond.initialPrice, initialPrice);
        assertEq(bond.finalPrice, finalPrice);
        assertEq(bond.endTime, bond.startTime + duration);

        // Switch to depositor
        vm.stopPrank();
        vm.startPrank(user1);

        // Mint USDC to user
        uint256 depositAmount = 10000e6; // 10000 USDC
        usdc.mint(user1, depositAmount);
        usdc.approve(address(bondDepository), depositAmount);

        // Calculate expected RZR payout at initial price
        uint256 expectedPayout = (depositAmount * 1e18) / initialPrice; // Should be 10000 RZR

        // Deposit to bond
        (uint256 payout, uint256 tokenId) = bondDepository.deposit(bondId, depositAmount, initialPrice, 0, user1);

        // Verify payout is correct (1500 USDC / 1.5 = 1000 RZR)
        assertEq(payout, expectedPayout);
        assertEq(payout, 5000e18); // Should receive 1000 RZR

        // Verify bond position
        IAppBondDepository.BondPosition memory position = bondDepository.positions(tokenId);
        assertEq(position.bondId, bondId);
        assertEq(position.amount, payout);
        assertEq(position.quoteAmount, depositAmount);
        assertEq(position.claimedAmount, 0);
        assertFalse(position.isStaked);

        // Verify bond state
        bond = bondDepository.getBond(bondId);
        assertEq(bond.sold, payout);
        assertEq(bond.purchased, depositAmount);

        // Fast forward half way through bond duration
        vm.warp(block.timestamp + duration / 2);

        // Calculate expected price at half way point
        uint256 expectedPrice = initialPrice - ((initialPrice - finalPrice) / 2);
        uint256 currentPrice = bondDepository.currentPrice(bondId);
        assertApproxEqRel(currentPrice, expectedPrice, 0.0001e18);

        // Fast forward to end of bond
        vm.warp(block.timestamp + duration);

        // Verify final price
        currentPrice = bondDepository.currentPrice(bondId);
        assertEq(currentPrice, finalPrice);

        // Fast forward past vesting period
        vm.warp(block.timestamp + bondDepository.bonds(bondId).vestingPeriod + 1);

        // Claim tokens
        uint256 balanceBefore = app.balanceOf(user1);
        bondDepository.claim(tokenId);

        // Verify tokens received
        assertEq(app.balanceOf(user1), balanceBefore + payout);

        vm.stopPrank();
    }

    // Tests to ensure treasury captures profit correctly when depositing at different price levels
    function test_TreasuryProfitCaptured_PremiumPrice() public {
        vm.startPrank(owner);

        // Price is higher than oracle price (premium)
        uint256 premiumPrice = 1.5e18; // 1.5 RZR per quote token
        uint256 finalPrice = 1e18; // Ensure initial > final
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            BOND_AMOUNT,
            premiumPrice,
            finalPrice,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );
        vm.stopPrank();

        // Prepare depositor
        vm.startPrank(user1);
        mockQuoteToken.mint(user1, BOND_AMOUNT);
        mockQuoteToken.approve(address(bondDepository), BOND_AMOUNT);

        // Record treasury stats before deposit
        uint256 initialExcessReserves = treasury.excessReserves();
        uint256 initialTotalReserves = treasury.totalReserves();
        uint256 initialTotalSupply = app.totalSupply();

        // Deposit
        (uint256 payout,) = bondDepository.deposit(bondId, BOND_AMOUNT, premiumPrice, 0, user1);

        // Expected calculations
        uint256 expectedReservesIncrease = BOND_AMOUNT; // 1:1 value in RZR terms since token price == RZR price
        uint256 expectedProfit = BOND_AMOUNT - payout; // Profit captured by treasury

        // Validate treasury state
        assertEq(
            treasury.totalReserves(), initialTotalReserves + expectedReservesIncrease, "Incorrect reserve increase"
        );
        assertEq(app.totalSupply(), initialTotalSupply + payout, "Incorrect total supply increase");
        assertApproxEqRel(
            treasury.excessReserves() - initialExcessReserves,
            expectedProfit,
            0.0001e18,
            "Treasury did not capture expected profit"
        );

        vm.stopPrank();
    }

    function test_TreasuryProfitCaptured_ParPrice() public {
        vm.startPrank(owner);

        // Price equal to oracle price (par) – expect zero profit
        uint256 parPrice = 1e18; // 1 RZR per quote token (matches oracle)
        uint256 finalPrice = 0.5e18; // Ensure initial > final
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            BOND_AMOUNT,
            parPrice,
            finalPrice,
            0,
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );
        vm.stopPrank();

        vm.startPrank(user1);
        mockQuoteToken.mint(user1, BOND_AMOUNT);
        mockQuoteToken.approve(address(bondDepository), BOND_AMOUNT);

        uint256 initialExcessReserves = treasury.excessReserves();

        // Deposit at par price
        bondDepository.deposit(bondId, BOND_AMOUNT, parPrice, 0, user1);

        // Since price equals oracle value, profit should be zero
        assertEq(treasury.excessReserves(), initialExcessReserves, "Unexpected profit captured at par price");

        vm.stopPrank();
    }

    function test_TreasuryProfitCaptured_DiscountPrice() public {
        vm.startPrank(owner);

        // Initial price above oracle, final below, we'll deposit near the end to get a discount price (< oracle)
        uint256 initialPrice = 1.1e18;
        uint256 finalPrice = 0.8e18;
        uint256 capacity = BOND_AMOUNT * 2; // Ensure sufficient capacity for larger payout
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            capacity,
            initialPrice,
            finalPrice,
            0, // min price
            BOND_DURATION,
            VESTING_PERIOD,
            STAKING_LOCK_PERIOD,
            false
        );

        // Fast-forward to just before bond end so current price ≈ finalPrice (< oracle)
        vm.warp(block.timestamp + BOND_DURATION - 1);

        uint256 currentPrice = bondDepository.currentPrice(bondId);
        assertTrue(currentPrice < 1e18, "Price should be below oracle for discount scenario");

        vm.stopPrank();

        // Depositor actions
        vm.startPrank(user1);
        mockQuoteToken.mint(user1, BOND_AMOUNT);
        mockQuoteToken.approve(address(bondDepository), BOND_AMOUNT);

        uint256 initialExcessReserves = treasury.excessReserves();

        // Expect no profit since payout > reserves value when price < oracle
        bondDepository.deposit(bondId, BOND_AMOUNT, currentPrice, 0, user1);

        assertEq(
            treasury.excessReserves(), initialExcessReserves, "Profit should be zero when depositing at discount price"
        );

        vm.stopPrank();
    }
}
