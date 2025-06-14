// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";

contract AppStakingTest is BaseTest {
    uint256 public constant STAKE_AMOUNT = 1000e18;
    uint256 public constant DECLARED_VALUE = 1000e18;
    uint256 public constant REWARD_AMOUNT = 100e18;

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);
        authority.addPolicy(owner);
    }

    function test_Initialize() public view {
        assertEq(address(staking.appToken()), address(app));
        assertEq(address(staking.trackingToken()), address(sapp));
        assertEq(staking.totalStaked(), 0);
    }

    function test_CreatePosition() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Verify position details
        IAppStaking.Position memory position = staking.positions(tokenId);

        assertEq(position.amount, STAKE_AMOUNT - 50e18);
        assertEq(position.declaredValue, DECLARED_VALUE);
        assertEq(position.cooldownEnd, 0);
        assertEq(staking.totalStaked(), STAKE_AMOUNT - 50e18);
        assertEq(sapp.balanceOf(owner), STAKE_AMOUNT - 50e18);

        vm.stopPrank();
    }

    function test_StartUnstaking() public {
        vm.startPrank(owner);

        // Create position first
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Verify cooldown state
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(position.cooldownEnd > 0);
        assertEq(position.cooldownEnd, block.timestamp + staking.withdrawCooldownPeriod());

        vm.stopPrank();
    }

    function test_CompleteUnstaking() public {
        vm.startPrank(owner);

        // Create position first
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId, uint256 taxPaid) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Start and complete unstaking
        staking.startUnstaking(tokenId);

        // Fast forward past cooldown period
        vm.warp(block.timestamp + staking.withdrawCooldownPeriod() + 1);

        uint256 balanceBefore = app.balanceOf(owner);
        staking.completeUnstaking(tokenId);

        // Verify tokens returned and position burned
        assertEq(app.balanceOf(owner), balanceBefore + STAKE_AMOUNT - taxPaid);
        assertEq(staking.totalStaked(), 0);
        assertEq(sapp.balanceOf(owner), 0);

        vm.stopPrank();
    }

    function test_ClaimRewards() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Add rewards
        app.mint(owner, REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);

        // Fast forward past reward cooldown
        vm.warp(block.timestamp + staking.rewardCooldownPeriod() + 1);

        // Claim rewards
        uint256 reward = staking.claimRewards(tokenId);
        assertTrue(reward > 0);

        vm.stopPrank();
    }

    function test_BuyPosition() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // taxes would've been paid
        assertEq(app.balanceOf(address(burner)), 50e18);

        app.mint(user1, DECLARED_VALUE);

        // Switch to buyer
        vm.stopPrank();
        vm.startPrank(user1);

        // Buy position
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify ownership transfer
        assertEq(staking.ownerOf(tokenId), user1);
        assertEq(sapp.balanceOf(user1), STAKE_AMOUNT - 50e18);
        assertEq(sapp.balanceOf(owner), 0);

        // no taxes earned but the burner gets 1% of the declared value
        assertEq(app.balanceOf(address(burner)), 60e18);

        vm.stopPrank();
    }

    function test_IncreaseAmount() public {
        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        IAppStaking.Position memory initialPosition = staking.positions(tokenId);
        assertEq(initialPosition.amount, STAKE_AMOUNT - 50e18);
        assertEq(initialPosition.declaredValue, DECLARED_VALUE);
        assertEq(staking.totalStaked(), STAKE_AMOUNT - 50e18);

        // Increase amount
        uint256 additionalAmount = 500e18;
        uint256 additionalDeclaredValue = 50e18;
        app.mint(owner, additionalAmount);
        app.approve(address(staking), additionalAmount);
        staking.increaseAmount(tokenId, additionalAmount, additionalDeclaredValue);

        // Verify position updated
        IAppStaking.Position memory finalPosition = staking.positions(tokenId);
        assertEq(finalPosition.amount, STAKE_AMOUNT + additionalAmount - 50e18 - 2.5e18);
        assertEq(finalPosition.declaredValue, DECLARED_VALUE + additionalDeclaredValue);
        assertEq(staking.totalStaked(), STAKE_AMOUNT + additionalAmount - 50e18 - 2.5e18);

        vm.stopPrank();
    }

    function test_CancelUnstaking() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Cancel unstaking
        staking.cancelUnstaking(tokenId);

        // Verify cooldown cancelled
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertEq(position.cooldownEnd, 0);

        vm.stopPrank();
    }

    function testFail_CreatePositionWithZeroAmount() public {
        vm.startPrank(owner);
        staking.createPosition(owner, 0, DECLARED_VALUE, 0);
        vm.stopPrank();
    }

    function testFail_CreatePositionWithZeroValue() public {
        vm.startPrank(owner);
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        staking.createPosition(owner, STAKE_AMOUNT, 0, 0);
        vm.stopPrank();
    }

    function testFail_StartUnstakingNotOwner() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        vm.stopPrank();

        // Try to start unstaking as non-owner
        vm.startPrank(user1);
        staking.startUnstaking(tokenId);
        vm.stopPrank();
    }

    function testFail_CompleteUnstakingBeforeCooldown() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Try to complete before cooldown
        staking.completeUnstaking(tokenId);

        vm.stopPrank();
    }

    function testFail_ClaimRewardsBeforeCooldown() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Add rewards
        app.mint(address(this), REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);

        // Try to claim before cooldown
        staking.claimRewards(tokenId);

        vm.stopPrank();
    }

    function testFail_BuyOwnPosition() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Try to buy own position
        app.mint(owner, DECLARED_VALUE);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        vm.stopPrank();
    }

    function test_RewardDistribution() public {
        vm.startPrank(owner);

        // Create two positions
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId1,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        app.mint(user1, STAKE_AMOUNT);

        vm.stopPrank();
        vm.startPrank(user1);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId2,) = staking.createPosition(user1, STAKE_AMOUNT, DECLARED_VALUE, 0);
        vm.stopPrank();

        // Add rewards
        vm.startPrank(owner);
        app.mint(owner, REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);

        // Fast forward to distribute rewards
        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Fast forward past reward cooldown
        vm.warp(block.timestamp + staking.rewardCooldownPeriod() + 1);

        // Claim rewards for both positions
        uint256 reward1 = staking.claimRewards(tokenId1);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 reward2 = staking.claimRewards(tokenId2);

        // Verify rewards are distributed equally
        assertEq(reward1, reward2);
        assertApproxEqAbs(reward1 + reward2, REWARD_AMOUNT, 1e18);

        vm.stopPrank();
    }

    function test_TaxDistribution() public {
        vm.startPrank(owner);

        // Create position with high declared value to test tax
        uint256 highValue = 10000e18;
        app.mint(owner, STAKE_AMOUNT + highValue);
        app.approve(address(staking), STAKE_AMOUNT + highValue);
        staking.createPosition(owner, STAKE_AMOUNT, highValue, 0);

        // Calculate expected tax distribution
        uint256 treasuryShare = (highValue * staking.harbergerTaxRate()) / staking.BASIS_POINTS();

        // Verify tax distribution
        assertEq(app.balanceOf(address(burner)), treasuryShare);

        vm.stopPrank();
    }

    function test_BuyerCanWithdrawAndClaimRewards() public {
        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Add rewards before selling
        app.mint(owner, REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);

        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Get earned rewards before selling
        uint256 earnedBefore = staking.earned(tokenId);

        // Prepare buyer
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Verify buyer owns the position
        assertEq(staking.ownerOf(tokenId), user1);
        assertEq(sapp.balanceOf(user1), STAKE_AMOUNT - 50e18);

        // Verify rewards were automatically claimed during purchase
        assertEq(app.balanceOf(user1), earnedBefore);

        // Start unstaking process
        staking.startUnstaking(tokenId);

        // Fast forward past cooldown period
        vm.warp(block.timestamp + staking.withdrawCooldownPeriod() + 1);

        // Complete unstaking
        uint256 balanceBefore = app.balanceOf(user1);
        staking.completeUnstaking(tokenId);

        // Verify tokens returned to buyer
        assertEq(app.balanceOf(user1), balanceBefore + STAKE_AMOUNT - 50e18);
        assertEq(staking.totalStaked(), 0);
        assertEq(sapp.balanceOf(user1), 0);

        vm.stopPrank();
    }

    function testFuzz_RewardDistribution(uint256 stakeAmount1, uint256 stakeAmount2, uint256 rewardAmount) public {
        // Bound the inputs to reasonable ranges
        stakeAmount1 = bound(stakeAmount1, 1e18, 1000000e18);
        stakeAmount2 = bound(stakeAmount2, 1e18, 1000000e18);
        rewardAmount = bound(rewardAmount, 1e18, 1000000e18);
        uint256 timeElapsed = staking.EPOCH_DURATION();

        vm.startPrank(owner);

        // Create two positions with different amounts
        app.mint(owner, stakeAmount1);
        app.approve(address(staking), stakeAmount1);
        (uint256 tokenId1,) = staking.createPosition(owner, stakeAmount1, stakeAmount1, 0);

        app.mint(user1, stakeAmount2);
        vm.stopPrank();

        vm.startPrank(user1);
        app.approve(address(staking), stakeAmount2);
        (uint256 tokenId2,) = staking.createPosition(user1, stakeAmount2, stakeAmount2, 0);
        vm.stopPrank();

        // Add rewards
        vm.startPrank(owner);
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Fast forward by random time
        vm.warp(block.timestamp + timeElapsed);

        // Get earned rewards before claiming
        uint256 earned1 = staking.earned(tokenId1);
        uint256 earned2 = staking.earned(tokenId2);

        // Verify rewards are proportional to stake amounts
        if (stakeAmount1 > 0 && stakeAmount2 > 0) {
            uint256 expectedRatio = (stakeAmount1 * 1e18) / stakeAmount2;
            uint256 actualRatio = (earned1 * 1e18) / earned2;
            assertApproxEqRel(actualRatio, expectedRatio, 0.01e18); // 1% tolerance
        }

        // Fast forward past reward cooldown
        vm.warp(block.timestamp + staking.rewardCooldownPeriod() + 1);

        // Claim rewards
        uint256 reward1 = staking.claimRewards(tokenId1);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 reward2 = staking.claimRewards(tokenId2);

        // Verify total rewards don't exceed notified amount
        assertTrue(reward1 + reward2 <= rewardAmount, "Total rewards exceed notified amount");

        // Verify claimed rewards match earned rewards
        assertEq(reward1, earned1, "Claimed rewards don't match earned rewards for position 1");
        assertEq(reward2, earned2, "Claimed rewards don't match earned rewards for position 2");

        vm.stopPrank();
    }

    function testFuzz_PositionOperations(
        uint256 stakeAmount,
        uint256 declaredValue,
        uint256 additionalAmount,
        uint256 additionalValue
    ) public {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        additionalAmount = bound(additionalAmount, 1e18, 1000000e18);
        additionalValue = bound(additionalValue, additionalAmount, additionalAmount * 2);

        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, stakeAmount + additionalAmount);
        app.approve(address(staking), stakeAmount + additionalAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, 0);

        // Get initial position details
        IAppStaking.Position memory initialPosition = staking.positions(tokenId);

        // Increase position
        staking.increaseAmount(tokenId, additionalAmount, additionalValue);

        // Get updated position details
        IAppStaking.Position memory finalPosition = staking.positions(tokenId);

        // Verify position was updated correctly
        assertApproxEqAbs(
            finalPosition.amount,
            initialPosition.amount + additionalAmount
                - ((additionalValue * staking.harbergerTaxRate()) / staking.BASIS_POINTS()),
            100,
            "Amount not updated correctly"
        );
        assertApproxEqAbs(
            finalPosition.declaredValue,
            initialPosition.declaredValue + additionalValue,
            100,
            "Declared value not updated correctly"
        );

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Verify cooldown started
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(position.cooldownEnd > 0, "Cooldown not started");

        // Cancel unstaking
        staking.cancelUnstaking(tokenId);

        // Verify cooldown cancelled
        IAppStaking.Position memory cooldownPosition = staking.positions(tokenId);
        assertEq(cooldownPosition.cooldownEnd, 0, "Cooldown not cancelled");

        vm.stopPrank();
    }

    function testFuzz_RewardAccumulation(uint256 stakeAmount, uint256 rewardAmount, uint256 timeBetweenRewards)
        public
    {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        rewardAmount = bound(rewardAmount, 1e18, 1000000e18);
        timeBetweenRewards = bound(timeBetweenRewards, 1, staking.EPOCH_DURATION() / 2);

        vm.startPrank(owner);

        // Create position
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, stakeAmount, 0);

        // Add first reward
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Fast forward
        vm.warp(block.timestamp + timeBetweenRewards);

        // Add second reward
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Fast forward past reward cooldown
        vm.warp(block.timestamp + staking.rewardCooldownPeriod() + 1);

        // Get earned rewards
        uint256 earned = staking.earned(tokenId);

        // Verify rewards don't exceed total notified amount
        assertTrue(earned <= rewardAmount * 2, "Earned rewards exceed total notified amount");

        // Claim rewards
        uint256 claimed = staking.claimRewards(tokenId);

        // Verify claimed amount matches earned amount
        assertEq(claimed, earned, "Claimed amount doesn't match earned amount");

        vm.stopPrank();
    }

    function testFuzz_BuyPosition(uint256 stakeAmount, uint256 declaredValue, uint256 rewardAmount) public {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        rewardAmount = bound(rewardAmount, 1e18, 1000000e18);

        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, 0);

        // Add rewards before selling
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Get earned rewards before selling
        uint256 earnedBefore = staking.earned(tokenId);

        // Prepare buyer
        app.mint(user1, declaredValue);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), declaredValue);
        staking.buyPosition(tokenId);

        uint256 totalTax = staking.harbergerTaxRate();

        // Verify buyer owns the position
        assertEq(staking.ownerOf(tokenId), user1, "Position ownership not transferred");
        assertApproxEqRel(
            sapp.balanceOf(user1),
            stakeAmount - ((declaredValue * totalTax) / staking.BASIS_POINTS()),
            0.0001e18,
            "Tracking tokens not transferred correctly"
        );

        // Verify seller received payment minus fees
        uint256 expectedSellerAmount =
            declaredValue - ((declaredValue * staking.resellFeeRate()) / staking.BASIS_POINTS());
        assertApproxEqRel(
            app.balanceOf(owner), expectedSellerAmount, 0.0001e18, "Seller did not receive correct amount"
        );

        // Verify rewards were automatically claimed during purchase
        assertEq(app.balanceOf(user1), earnedBefore, "Rewards not automatically claimed during purchase");

        // Fast forward past reward cooldown
        vm.warp(block.timestamp + staking.rewardCooldownPeriod() + 1);

        // Verify no additional rewards to claim
        uint256 earnedAfter = staking.earned(tokenId);
        assertEq(earnedAfter, 0, "Additional rewards found after automatic claim");

        vm.stopPrank();
    }

    function testFuzz_BuyPositionWithRewards(
        uint256 stakeAmount,
        uint256 declaredValue,
        uint256 rewardAmount1,
        uint256 rewardAmount2
    ) public {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        rewardAmount1 = bound(rewardAmount1, 1e18, 1000000e18);
        rewardAmount2 = bound(rewardAmount2, 1e18, 1000000e18);

        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, 0);

        // Add first reward
        app.mint(owner, rewardAmount1);
        app.approve(address(staking), rewardAmount1);
        staking.notifyRewardAmount(rewardAmount1);

        // Fast forward half the epoch
        vm.warp(block.timestamp + staking.EPOCH_DURATION() / 2);

        // Add second reward
        app.mint(owner, rewardAmount2);
        app.approve(address(staking), rewardAmount2);
        staking.notifyRewardAmount(rewardAmount2);

        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Get earned rewards before selling
        uint256 earnedBefore = staking.earned(tokenId);
        assertGt(earnedBefore, 0, "No rewards earned before purchase");

        // Prepare buyer
        app.mint(user1, declaredValue);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), declaredValue);
        staking.buyPosition(tokenId);

        // Fast forward past reward cooldown
        vm.warp(block.timestamp + staking.rewardCooldownPeriod() + 1);

        // Verify buyer can claim accumulated rewards
        uint256 earnedAfter = staking.earned(tokenId);
        assertEq(earnedAfter, 0, "Additional rewards found after automatic claim");

        vm.stopPrank();
    }

    function testFuzz_BuyPositionWithUnstaking(uint256 stakeAmount, uint256 declaredValue, uint256 rewardAmount)
        public
    {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        rewardAmount = bound(rewardAmount, 1e18, 1000000e18);

        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, 0);

        // Add rewards
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Prepare buyer
        app.mint(user1, declaredValue);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), declaredValue);
        staking.buyPosition(tokenId);

        // Verify unstaking was cancelled
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertEq(position.cooldownEnd, 0, "Unstaking not cancelled after position transfer");

        // Fast forward past reward cooldown
        vm.warp(block.timestamp + staking.rewardCooldownPeriod() + 1);

        // Verify buyer can claim rewards
        uint256 earned = staking.earned(tokenId);
        uint256 claimed = staking.claimRewards(tokenId);
        assertEq(claimed, earned, "Buyer could not claim rewards");

        vm.stopPrank();
    }

    function test_SplitPosition() public {
        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Add rewards before splitting
        app.mint(owner, REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);

        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Get initial position details
        IAppStaking.Position memory initialPosition = staking.positions(tokenId);

        // Split position 50/50
        uint256 splitRatio = 0.5e18; // 50%
        uint256 newTokenId = staking.splitPosition(tokenId, splitRatio, user1);

        // Get final position details
        IAppStaking.Position memory originalPosition = staking.positions(tokenId);
        IAppStaking.Position memory newPosition = staking.positions(newTokenId);

        // Verify original position was reduced correctly
        assertEq(originalPosition.amount, initialPosition.amount - (initialPosition.amount * splitRatio / 1e18));
        assertEq(
            originalPosition.declaredValue,
            initialPosition.declaredValue - (initialPosition.declaredValue * splitRatio / 1e18)
        );

        // Verify new position was created correctly
        assertEq(newPosition.amount, initialPosition.amount * splitRatio / 1e18);
        assertEq(newPosition.declaredValue, initialPosition.declaredValue * splitRatio / 1e18);
        assertEq(newPosition.rewards, 0);
        assertEq(newPosition.rewardPerTokenPaid, staking.rewardPerTokenStored());

        // Verify tracking tokens were transferred correctly
        assertEq(sapp.balanceOf(owner), originalPosition.amount);
        assertEq(sapp.balanceOf(user1), newPosition.amount);

        // Verify NFT ownership
        assertEq(staking.ownerOf(tokenId), owner);
        assertEq(staking.ownerOf(newTokenId), user1);

        vm.stopPrank();
    }

    function testFail_SplitPositionNotOwner() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        vm.stopPrank();

        // Try to split as non-owner
        vm.startPrank(user1);
        staking.splitPosition(tokenId, 0.5e18, user2);
        vm.stopPrank();
    }

    function testFail_SplitPositionInCooldown() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Start unstaking
        staking.startUnstaking(tokenId);

        // Try to split while in cooldown
        staking.splitPosition(tokenId, 0.5e18, user1);

        vm.stopPrank();
    }

    function testFail_SplitPositionInvalidRatio() public {
        vm.startPrank(owner);

        // Create position
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Try to split with invalid ratio
        staking.splitPosition(tokenId, 1.1e18, user1); // 110%

        vm.stopPrank();
    }

    function testFuzz_SplitPosition(
        uint256 stakeAmount,
        uint256 declaredValue,
        uint256 splitRatio,
        uint256 rewardAmount
    ) public {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        splitRatio = bound(splitRatio, 1, 0.99e18); // Max 99% split
        rewardAmount = bound(rewardAmount, 1e18, 1000000e18);

        vm.startPrank(owner);

        // Create initial position
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, 0);

        // Add rewards
        app.mint(owner, rewardAmount);
        app.approve(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);

        // Fast forward to accumulate rewards
        vm.warp(block.timestamp + staking.EPOCH_DURATION());

        // Get initial position details
        IAppStaking.Position memory initialPosition = staking.positions(tokenId);

        // Split position
        uint256 newTokenId = staking.splitPosition(tokenId, splitRatio, user1);

        // Get final position details
        IAppStaking.Position memory originalPosition = staking.positions(tokenId);
        IAppStaking.Position memory newPosition = staking.positions(newTokenId);

        // Calculate expected split amounts
        uint256 expectedSplitAmount = (initialPosition.amount * splitRatio) / 1e18;
        uint256 expectedSplitValue = (initialPosition.declaredValue * splitRatio) / 1e18;

        // Verify amounts were split correctly
        assertEq(newPosition.amount, expectedSplitAmount);
        assertEq(newPosition.declaredValue, expectedSplitValue);
        assertEq(originalPosition.amount, initialPosition.amount - expectedSplitAmount);
        assertEq(originalPosition.declaredValue, initialPosition.declaredValue - expectedSplitValue);

        // Verify tracking tokens were transferred correctly
        assertEq(sapp.balanceOf(owner), originalPosition.amount);
        assertEq(sapp.balanceOf(user1), newPosition.amount);

        // Verify NFT ownership
        assertEq(staking.ownerOf(tokenId), owner);
        assertEq(staking.ownerOf(newTokenId), user1);

        // Verify rewards start fresh for new position
        assertEq(newPosition.rewards, 0);
        assertEq(newPosition.rewardPerTokenPaid, staking.rewardPerTokenStored());

        vm.stopPrank();
    }
}
