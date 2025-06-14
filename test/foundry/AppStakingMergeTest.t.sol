// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";

contract AppStakingMergeTest is BaseTest {
    uint256 public constant STAKE_AMOUNT_1 = 1000e18;
    uint256 public constant STAKE_AMOUNT_2 = 500e18;

    function setUp() public {
        setUpBaseTest();

        // Give the owner policy permissions to create positions, notify rewards, etc.
        vm.startPrank(owner);
        authority.addPolicy(owner);
        vm.stopPrank();
    }

    function _createPosition(uint256 amount, uint256 declaredValue)
        internal
        returns (uint256 tokenId, uint256 netStaked, uint256 taxPaid)
    {
        vm.startPrank(owner);
        app.mint(owner, amount);
        app.approve(address(staking), amount);
        (tokenId, taxPaid) = staking.createPosition(owner, amount, declaredValue, 0);
        vm.stopPrank();

        netStaked = amount - taxPaid;
    }

    function test_MergePositions() public {
        // Create two positions for the owner
        (uint256 tokenId1, uint256 net1,) = _createPosition(STAKE_AMOUNT_1, STAKE_AMOUNT_1);
        (uint256 tokenId2, uint256 net2,) = _createPosition(STAKE_AMOUNT_2, STAKE_AMOUNT_2);

        // Pre-merge assertions
        assertEq(staking.balanceOf(owner), 2, "Owner should have two NFTs before merge");

        uint256 totalBefore = staking.totalStaked();
        assertEq(totalBefore, net1 + net2, "Total staked mismatch before merge");

        // Merge the positions (tokenId1 survives)
        vm.startPrank(owner);
        uint256 returnedId = staking.mergePositions(tokenId1, tokenId2);
        vm.stopPrank();

        // Returned Id should equal the surviving tokenId1
        assertEq(returnedId, tokenId1, "Returned tokenId should be the surviving one");

        // Owner should now have only one NFT
        assertEq(staking.balanceOf(owner), 1, "Owner should have one NFT after merge");
        assertEq(staking.ownerOf(tokenId1), owner, "Owner should own surviving position");

        // Verify merged position details
        IAppStaking.Position memory mergedPosition = staking.positions(tokenId1);
        assertEq(mergedPosition.amount, net1 + net2, "Merged stake amount incorrect");
        assertEq(mergedPosition.declaredValue, STAKE_AMOUNT_1 + STAKE_AMOUNT_2, "Merged declared value incorrect");

        // Total staked should remain unchanged
        assertEq(staking.totalStaked(), totalBefore, "Total staked should not change after merge");

        // Tracking token balance should remain unchanged (equal to combined net stake)
        assertEq(sapp.balanceOf(owner), mergedPosition.amount, "sRZR balance mismatch after merge");

        // Accessing burned tokenId2 should revert
        vm.expectRevert();
        staking.ownerOf(tokenId2);
    }

    function testFail_MergePositions_NotOwner() public {
        // Create first position for owner
        (uint256 tokenId1,,) = _createPosition(STAKE_AMOUNT_1, STAKE_AMOUNT_1);

        // Create second position for user1
        vm.startPrank(user1);
        app.mint(user1, STAKE_AMOUNT_2);
        app.approve(address(staking), STAKE_AMOUNT_2);
        (uint256 tokenId2,) = staking.createPosition(user1, STAKE_AMOUNT_2, STAKE_AMOUNT_2, 0);
        vm.stopPrank();

        // Attempt merge from owner (doesn't own tokenId2) should fail
        vm.startPrank(owner);
        staking.mergePositions(tokenId1, tokenId2);
    }
}
