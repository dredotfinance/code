// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";

contract StakingMinLockDurationTest is BaseTest {
    uint256 public constant STAKE_AMOUNT = 1000e18;
    uint256 public constant DECLARED_VALUE = 1000e18;
    uint256 public constant SHORT_LOCK_DURATION = 1 days;
    uint256 public constant LONG_LOCK_DURATION = 7 days;
    uint256 public constant VERY_LONG_LOCK_DURATION = 30 days;

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);
        authority.addPolicy(owner);
    }

    // ============ BASIC MIN LOCK DURATION TESTS ============

    function test_CreatePositionWithMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position with min lock duration
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, SHORT_LOCK_DURATION);

        // Check withdraw cooldown status - should use the max of min lock duration and default withdraw cooldown
        (bool inCooldown, uint256 cooldownEnd) = staking.isInWithdrawCooldown(tokenId);
        assertTrue(inCooldown, "Position should be in withdraw cooldown");

        uint256 expectedCooldownEnd = block.timestamp + Math.max(SHORT_LOCK_DURATION, staking.withdrawCooldownPeriod());
        assertEq(
            cooldownEnd,
            expectedCooldownEnd,
            "Cooldown end time should match max of min lock duration and default withdraw cooldown"
        );

        vm.stopPrank();
    }

    function test_CreatePositionWithZeroMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position with zero min lock duration
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, 0);

        // Check withdraw cooldown status - should use default withdraw cooldown period
        (bool inCooldown, uint256 cooldownEnd) = staking.isInWithdrawCooldown(tokenId);
        assertTrue(inCooldown, "Position should be in withdraw cooldown");
        assertEq(
            cooldownEnd,
            block.timestamp + staking.withdrawCooldownPeriod(),
            "Cooldown end time should match default withdraw cooldown period"
        );

        vm.stopPrank();
    }

    function test_CreatePositionWithMinLockDurationGreaterThanDefault() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position with min lock duration greater than default
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, LONG_LOCK_DURATION);

        // Check withdraw cooldown status
        (bool inCooldown, uint256 cooldownEnd) = staking.isInWithdrawCooldown(tokenId);
        assertTrue(inCooldown, "Position should be in withdraw cooldown");
        assertEq(cooldownEnd, block.timestamp + LONG_LOCK_DURATION, "Cooldown end time should match min lock duration");

        vm.stopPrank();
    }

    function test_CannotStartUnstakingBeforeMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position with min lock duration
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, SHORT_LOCK_DURATION);

        // Try to start unstaking before min lock duration expires
        vm.expectRevert("Currently in withdraw cooldown");
        staking.startUnstaking(tokenId);

        vm.stopPrank();
    }

    function test_CanStartUnstakingAfterMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position with min lock duration
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, SHORT_LOCK_DURATION);

        // Get the actual cooldown end time
        (, uint256 cooldownEnd) = staking.isInWithdrawCooldown(tokenId);
        uint256 actualCooldownDuration = cooldownEnd - block.timestamp;

        // Fast forward past the actual cooldown duration
        vm.warp(block.timestamp + actualCooldownDuration + 1);

        // Should be able to start unstaking now
        staking.startUnstaking(tokenId);

        // Verify unstaking cooldown started
        IAppStaking.Position memory position = staking.positions(tokenId);
        assertTrue(position.cooldownEnd > 0, "Unstaking cooldown should have started");

        vm.stopPrank();
    }

    // ============ SPLIT POSITION TESTS ============

    function test_SplitPositionInheritsMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position with min lock duration
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, LONG_LOCK_DURATION);

        // Get original cooldown end time
        (bool inCooldown, uint256 originalCooldownEnd) = staking.isInWithdrawCooldown(tokenId);
        assertTrue(inCooldown, "Original position should be in withdraw cooldown");

        // Split position
        uint256 splitRatio = 0.5e18; // 50%
        uint256 newTokenId = staking.splitPosition(tokenId, splitRatio, user1);

        // Check that both positions inherit the same withdraw cooldown
        (bool inCooldown1, uint256 cooldownEnd1) = staking.isInWithdrawCooldown(tokenId);
        (bool inCooldown2, uint256 cooldownEnd2) = staking.isInWithdrawCooldown(newTokenId);

        assertTrue(inCooldown1, "Original position should still be in withdraw cooldown");
        assertTrue(inCooldown2, "Split position should inherit withdraw cooldown");
        assertEq(cooldownEnd1, originalCooldownEnd, "Original position cooldown should remain unchanged");
        assertEq(cooldownEnd2, originalCooldownEnd, "Split position should inherit same cooldown end time");

        vm.stopPrank();
    }

    function test_SplitPositionCannotStartUnstakingBeforeMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position with min lock duration
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, LONG_LOCK_DURATION);

        // Split position
        uint256 splitRatio = 0.5e18; // 50%
        uint256 newTokenId = staking.splitPosition(tokenId, splitRatio, user1);

        // Try to start unstaking on original position before min lock duration expires
        vm.expectRevert("Currently in withdraw cooldown");
        staking.startUnstaking(tokenId);

        // Try to start unstaking on split position before min lock duration expires
        vm.stopPrank();
        vm.startPrank(user1);
        vm.expectRevert("Currently in withdraw cooldown");
        staking.startUnstaking(newTokenId);

        vm.stopPrank();
    }

    function test_SplitPositionCanStartUnstakingAfterMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position with min lock duration
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, SHORT_LOCK_DURATION);

        // Split position
        uint256 splitRatio = 0.5e18; // 50%
        uint256 newTokenId = staking.splitPosition(tokenId, splitRatio, user1);

        // Get the actual cooldown end time
        (, uint256 cooldownEnd) = staking.isInWithdrawCooldown(tokenId);
        uint256 actualCooldownDuration = cooldownEnd - block.timestamp;

        // Fast forward past the actual cooldown duration
        vm.warp(block.timestamp + actualCooldownDuration + 1);

        // Should be able to start unstaking on original position
        staking.startUnstaking(tokenId);

        // Should be able to start unstaking on split position
        vm.stopPrank();
        vm.startPrank(user1);
        staking.startUnstaking(newTokenId);

        // Verify both positions can start unstaking
        IAppStaking.Position memory position1 = staking.positions(tokenId);
        IAppStaking.Position memory position2 = staking.positions(newTokenId);
        assertTrue(position1.cooldownEnd > 0, "Original position unstaking should have started");
        assertTrue(position2.cooldownEnd > 0, "Split position unstaking should have started");

        vm.stopPrank();
    }

    // ============ MERGE POSITION TESTS ============

    function test_MergePositionsInheritsStrictestMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT * 2);
        app.approve(address(staking), STAKE_AMOUNT * 2);

        // Create two positions with different min lock durations
        (uint256 tokenId1,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, SHORT_LOCK_DURATION);
        (uint256 tokenId2,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, LONG_LOCK_DURATION);

        // Get cooldown end times
        (bool inCooldown1, uint256 cooldownEnd1) = staking.isInWithdrawCooldown(tokenId1);
        (bool inCooldown2, uint256 cooldownEnd2) = staking.isInWithdrawCooldown(tokenId2);

        assertTrue(inCooldown1, "Position 1 should be in withdraw cooldown");
        assertTrue(inCooldown2, "Position 2 should be in withdraw cooldown");
        assertGt(cooldownEnd2, cooldownEnd1, "Position 2 should have longer cooldown");

        // Merge positions
        uint256 mergedTokenId = staking.mergePositions(tokenId1, tokenId2);

        // Check that merged position inherits the strictest (longest) cooldown
        (bool inCooldownMerged, uint256 cooldownEndMerged) = staking.isInWithdrawCooldown(mergedTokenId);

        assertTrue(inCooldownMerged, "Merged position should be in withdraw cooldown");
        assertEq(cooldownEndMerged, cooldownEnd2, "Merged position should inherit the longest cooldown");

        vm.stopPrank();
    }

    function test_MergePositionsCannotStartUnstakingBeforeStrictestMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT * 2);
        app.approve(address(staking), STAKE_AMOUNT * 2);

        // Create two positions with different min lock durations
        (uint256 tokenId1,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, SHORT_LOCK_DURATION);
        (uint256 tokenId2,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, LONG_LOCK_DURATION);

        // Merge positions
        uint256 mergedTokenId = staking.mergePositions(tokenId1, tokenId2);

        // Try to start unstaking before the strictest min lock duration expires
        vm.expectRevert("Currently in withdraw cooldown");
        staking.startUnstaking(mergedTokenId);

        vm.stopPrank();
    }

    function test_MergePositionsCanStartUnstakingAfterStrictestMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT * 2);
        app.approve(address(staking), STAKE_AMOUNT * 2);

        // Create two positions with different min lock durations
        (uint256 tokenId1,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, SHORT_LOCK_DURATION);
        (uint256 tokenId2,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, LONG_LOCK_DURATION);

        // Merge positions
        uint256 mergedTokenId = staking.mergePositions(tokenId1, tokenId2);

        // Get the actual cooldown end time
        (, uint256 cooldownEnd) = staking.isInWithdrawCooldown(mergedTokenId);
        uint256 actualCooldownDuration = cooldownEnd - block.timestamp;

        // Fast forward past the strictest min lock duration
        vm.warp(block.timestamp + actualCooldownDuration + 1);

        // Should be able to start unstaking now
        staking.startUnstaking(mergedTokenId);

        // Verify unstaking cooldown started
        IAppStaking.Position memory position = staking.positions(mergedTokenId);
        assertTrue(position.cooldownEnd > 0, "Unstaking cooldown should have started");

        vm.stopPrank();
    }

    // ============ COMPLEX SCENARIO TESTS ============

    function test_SplitThenMergeInheritsOriginalMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT * 2);
        app.approve(address(staking), STAKE_AMOUNT * 2);

        // Create position with min lock duration
        (uint256 tokenId1,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, LONG_LOCK_DURATION);
        (uint256 tokenId2,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, SHORT_LOCK_DURATION);

        // Split the first position
        uint256 splitRatio = 0.5e18; // 50%
        uint256 splitTokenId = staking.splitPosition(tokenId1, splitRatio, user1);

        // Get original cooldown end times
        (bool inCooldown1, uint256 cooldownEnd1) = staking.isInWithdrawCooldown(tokenId1);
        (bool inCooldown2, uint256 cooldownEnd2) = staking.isInWithdrawCooldown(tokenId2);
        (bool inCooldownSplit, uint256 cooldownEndSplit) = staking.isInWithdrawCooldown(splitTokenId);

        // Transfer the second position to user1 so they can merge
        staking.transferFrom(owner, user1, tokenId2);

        // Merge the split position with the second position (both owned by user1)
        vm.stopPrank();
        vm.startPrank(user1);
        app.approve(address(staking), STAKE_AMOUNT * 2);
        uint256 mergedTokenId = staking.mergePositions(splitTokenId, tokenId2);

        // Check that merged position inherits the strictest cooldown (LONG_LOCK_DURATION from split position)
        (bool inCooldownMerged, uint256 cooldownEndMerged) = staking.isInWithdrawCooldown(mergedTokenId);

        assertTrue(inCooldownMerged, "Merged position should be in withdraw cooldown");
        assertEq(
            cooldownEndMerged, cooldownEnd1, "Merged position should inherit the longest cooldown from split position"
        );

        vm.stopPrank();
    }

    function test_MultipleSplitsInheritOriginalMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT * 4);
        app.approve(address(staking), STAKE_AMOUNT * 4);

        // Create position with min lock duration
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, LONG_LOCK_DURATION);

        // Get original cooldown end time
        (bool inCooldown, uint256 originalCooldownEnd) = staking.isInWithdrawCooldown(tokenId);

        // Split position multiple times
        uint256 split1TokenId = staking.splitPosition(tokenId, 0.25e18, user1); // 25%
        uint256 split2TokenId = staking.splitPosition(tokenId, 0.25e18, user2); // 25%
        uint256 split3TokenId = staking.splitPosition(tokenId, 0.25e18, user3); // 25%

        // Check that all split positions inherit the same cooldown
        (bool inCooldown1, uint256 cooldownEnd1) = staking.isInWithdrawCooldown(split1TokenId);
        (bool inCooldown2, uint256 cooldownEnd2) = staking.isInWithdrawCooldown(split2TokenId);
        (bool inCooldown3, uint256 cooldownEnd3) = staking.isInWithdrawCooldown(split3TokenId);

        assertTrue(inCooldown1, "Split 1 should be in withdraw cooldown");
        assertTrue(inCooldown2, "Split 2 should be in withdraw cooldown");
        assertTrue(inCooldown3, "Split 3 should be in withdraw cooldown");
        assertEq(cooldownEnd1, originalCooldownEnd, "Split 1 should inherit original cooldown");
        assertEq(cooldownEnd2, originalCooldownEnd, "Split 2 should inherit original cooldown");
        assertEq(cooldownEnd3, originalCooldownEnd, "Split 3 should inherit original cooldown");

        vm.stopPrank();
    }

    // ============ FUZZ TESTS ============

    function testFuzz_MinLockDurationWithSplit(
        uint256 stakeAmount,
        uint256 declaredValue,
        uint256 minLockDuration,
        uint256 splitRatio
    ) public {
        // Bound the inputs to reasonable ranges
        stakeAmount = bound(stakeAmount, 1e18, 1000000e18);
        declaredValue = bound(declaredValue, stakeAmount, stakeAmount * 2);
        minLockDuration = bound(minLockDuration, 1 hours, 365 days);
        splitRatio = bound(splitRatio, 1, 0.99e18); // Max 99% split

        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, stakeAmount);
        app.approve(address(staking), stakeAmount);

        // Create position with min lock duration
        (uint256 tokenId,) = staking.createPosition(owner, stakeAmount, declaredValue, minLockDuration);

        // Get original cooldown end time
        (bool inCooldown, uint256 originalCooldownEnd) = staking.isInWithdrawCooldown(tokenId);
        assertTrue(inCooldown, "Position should be in withdraw cooldown");

        // Split position
        uint256 newTokenId = staking.splitPosition(tokenId, splitRatio, user1);

        // Check that both positions inherit the same cooldown
        (bool inCooldown1, uint256 cooldownEnd1) = staking.isInWithdrawCooldown(tokenId);
        (bool inCooldown2, uint256 cooldownEnd2) = staking.isInWithdrawCooldown(newTokenId);

        assertTrue(inCooldown1, "Original position should still be in withdraw cooldown");
        assertTrue(inCooldown2, "Split position should inherit withdraw cooldown");
        assertEq(cooldownEnd1, originalCooldownEnd, "Original position cooldown should remain unchanged");
        assertEq(cooldownEnd2, originalCooldownEnd, "Split position should inherit same cooldown end time");

        vm.stopPrank();
    }

    function testFuzz_MinLockDurationWithMerge(
        uint256 stakeAmount1,
        uint256 stakeAmount2,
        uint256 declaredValue1,
        uint256 declaredValue2,
        uint256 minLockDuration1,
        uint256 minLockDuration2
    ) public {
        // Bound the inputs to reasonable ranges
        stakeAmount1 = bound(stakeAmount1, 1e18, 1000000e18);
        stakeAmount2 = bound(stakeAmount2, 1e18, 1000000e18);
        declaredValue1 = bound(declaredValue1, stakeAmount1, stakeAmount1 * 2);
        declaredValue2 = bound(declaredValue2, stakeAmount2, stakeAmount2 * 2);
        minLockDuration1 = bound(minLockDuration1, 1 hours, 365 days);
        minLockDuration2 = bound(minLockDuration2, 1 hours, 365 days);

        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, stakeAmount1 + stakeAmount2);
        app.approve(address(staking), stakeAmount1 + stakeAmount2);

        // Create two positions with different min lock durations
        (uint256 tokenId1,) = staking.createPosition(owner, stakeAmount1, declaredValue1, minLockDuration1);
        (uint256 tokenId2,) = staking.createPosition(owner, stakeAmount2, declaredValue2, minLockDuration2);

        // Get cooldown end times
        (bool inCooldown1, uint256 cooldownEnd1) = staking.isInWithdrawCooldown(tokenId1);
        (bool inCooldown2, uint256 cooldownEnd2) = staking.isInWithdrawCooldown(tokenId2);

        assertTrue(inCooldown1, "Position 1 should be in withdraw cooldown");
        assertTrue(inCooldown2, "Position 2 should be in withdraw cooldown");

        // Merge positions
        uint256 mergedTokenId = staking.mergePositions(tokenId1, tokenId2);

        // Check that merged position inherits the strictest (longest) cooldown
        (bool inCooldownMerged, uint256 cooldownEndMerged) = staking.isInWithdrawCooldown(mergedTokenId);

        assertTrue(inCooldownMerged, "Merged position should be in withdraw cooldown");

        uint256 expectedCooldownEnd = cooldownEnd1 > cooldownEnd2 ? cooldownEnd1 : cooldownEnd2;
        assertEq(cooldownEndMerged, expectedCooldownEnd, "Merged position should inherit the longest cooldown");

        vm.stopPrank();
    }

    // ============ EDGE CASE TESTS ============

    function test_CreatePositionWithVeryLongMinLockDuration() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position with very long min lock duration
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, VERY_LONG_LOCK_DURATION);

        // Check withdraw cooldown status
        (bool inCooldown, uint256 cooldownEnd) = staking.isInWithdrawCooldown(tokenId);
        assertTrue(inCooldown, "Position should be in withdraw cooldown");
        assertEq(
            cooldownEnd,
            block.timestamp + VERY_LONG_LOCK_DURATION,
            "Cooldown end time should match very long min lock duration"
        );

        // Try to start unstaking before very long min lock duration expires
        vm.expectRevert("Currently in withdraw cooldown");
        staking.startUnstaking(tokenId);

        // Fast forward past very long min lock duration
        vm.warp(block.timestamp + VERY_LONG_LOCK_DURATION + 1);

        // Should be able to start unstaking now
        staking.startUnstaking(tokenId);

        vm.stopPrank();
    }

    function test_MinLockDurationWithBuyPosition() public {
        vm.startPrank(owner);

        // Mint RZR tokens to owner
        app.mint(owner, STAKE_AMOUNT);
        app.approve(address(staking), STAKE_AMOUNT);

        // Create position with min lock duration
        (uint256 tokenId,) = staking.createPosition(owner, STAKE_AMOUNT, DECLARED_VALUE, LONG_LOCK_DURATION);

        // Get original cooldown end time
        (bool inCooldown, uint256 originalCooldownEnd) = staking.isInWithdrawCooldown(tokenId);

        // Prepare buyer
        app.mint(user1, DECLARED_VALUE);
        vm.stopPrank();

        // Buyer purchases the position
        vm.startPrank(user1);
        app.approve(address(staking), DECLARED_VALUE);
        staking.buyPosition(tokenId);

        // Check that buyer inherits the same withdraw cooldown
        (bool inCooldownAfter, uint256 cooldownEndAfter) = staking.isInWithdrawCooldown(tokenId);

        assertTrue(inCooldownAfter, "Position should still be in withdraw cooldown after purchase");
        assertEq(cooldownEndAfter, originalCooldownEnd, "Buyer should inherit the same cooldown end time");

        // Try to start unstaking before min lock duration expires
        vm.expectRevert("Currently in withdraw cooldown");
        staking.startUnstaking(tokenId);

        vm.stopPrank();
    }
}
