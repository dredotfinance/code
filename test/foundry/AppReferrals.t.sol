// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/core/AppReferrals.sol";
import "../../contracts/core/AppBondDepository.sol";
import "../../contracts/core/AppStaking.sol";
import "../../contracts/core/RZR.sol";
import "../../contracts/core/AppTreasury.sol";
import "../../contracts/core/AppAuthority.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AppReferralsTest is BaseTest {
    AppReferrals public referrals;

    address public MERKLE_SERVER = makeAddr("merkle_server");
    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");
    address public CHARLIE = makeAddr("charlie");

    // Events
    event ReferralCodeRegistered(address indexed referrer, bytes8 code);
    event ReferralRegistered(address indexed referred, address indexed referrer, bytes8 code);
    event RewardsClaimed(address indexed user, uint256 amount, bytes32 root);

    function setUp() public {
        // Setup base contracts
        setUpBaseTest();

        // Setup referrals contract
        referrals = new AppReferrals();
        referrals.initialize(
            address(bondDepository), address(staking), address(app), address(treasury), address(authority), address(0)
        );

        // Set merkle server
        vm.startPrank(owner);
        referrals.setMerkleServer(MERKLE_SERVER);
        authority.addPolicy(MERKLE_SERVER);
        vm.stopPrank();

        // Label addresses for better trace output

        vm.label(MERKLE_SERVER, "MERKLE_SERVER");
        vm.label(ALICE, "ALICE");
        vm.label(BOB, "BOB");
        vm.label(CHARLIE, "CHARLIE");
    }

    function testReferralCodeGeneration() public {
        // Alice generates a referral code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));

        vm.expectEmit(true, true, false, true);
        emit ReferralCodeRegistered(ALICE, aliceCode);
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Verify code is registered
        assertEq(referrals.referralCodes(aliceCode), ALICE);
        assertEq(referrals.referrerCodes(ALICE), aliceCode);
    }

    function testReferralTracking() public {
        // Alice generates a referral code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Bob uses Alice's referral code to stake
        vm.startPrank(BOB);
        uint256 stakeAmount = 1000e18;
        deal(address(app), BOB, stakeAmount);
        app.approve(address(referrals), stakeAmount);

        vm.expectEmit(true, true, false, true);
        emit ReferralRegistered(BOB, ALICE, aliceCode);
        referrals.stakeWithReferral(stakeAmount, stakeAmount, aliceCode);
        vm.stopPrank();

        // Verify referral is tracked
        address[] memory aliceReferrals = referrals.getReferrals(ALICE);
        assertEq(aliceReferrals.length, 1);
        assertEq(aliceReferrals[0], BOB);
        assertEq(referrals.trackedReferrals(BOB), ALICE);
    }

    function testMerkleRewards() public {
        // Setup: Alice refers Bob and Charlie
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        vm.prank(ALICE);
        referrals.registerReferralCode(aliceCode);

        // Bob and Charlie stake using Alice's code
        uint256 stakeAmount = 1000e18;

        vm.startPrank(BOB);
        deal(address(app), BOB, stakeAmount);
        app.approve(address(referrals), stakeAmount);
        referrals.stakeWithReferral(stakeAmount, stakeAmount, aliceCode);
        vm.stopPrank();

        vm.startPrank(CHARLIE);
        deal(address(app), CHARLIE, stakeAmount);
        app.approve(address(referrals), stakeAmount);
        referrals.stakeWithReferral(stakeAmount, stakeAmount, aliceCode);
        vm.stopPrank();

        // Create merkle tree with rewards
        // Alice gets 100 RZR for referring Bob and Charlie
        uint256 aliceReward = 100e18;
        bytes32[] memory aliceProof = new bytes32[](1);
        aliceProof[0] = keccak256(abi.encodePacked("dummy proof")); // In reality, this would be generated off-chain

        bytes32 aliceLeaf = keccak256(abi.encodePacked(ALICE, aliceReward));
        bytes32 merkleRoot = keccak256(abi.encodePacked(aliceLeaf, aliceProof[0]));

        // Merkle server adds rewards
        vm.startPrank(MERKLE_SERVER);
        deal(address(app), MERKLE_SERVER, aliceReward);
        app.approve(address(referrals), aliceReward);
        referrals.addMerkleRoot(merkleRoot, aliceReward);
        vm.stopPrank();

        // Alice claims her rewards
        vm.startPrank(ALICE);
        IAppReferrals.ClaimRewardsInput[] memory inputs = new IAppReferrals.ClaimRewardsInput[](1);
        inputs[0] =
            IAppReferrals.ClaimRewardsInput({root: merkleRoot, user: ALICE, amount: aliceReward, proofs: aliceProof});

        vm.expectEmit(true, false, false, true);
        emit RewardsClaimed(ALICE, aliceReward, merkleRoot);
        referrals.claimRewards(inputs);
        vm.stopPrank();

        // Verify rewards were claimed
        (uint256 totalAmount, uint256 claimedAmount) = referrals.getMerkleRootInfo(merkleRoot);
        assertEq(totalAmount, aliceReward);
        assertEq(claimedAmount, aliceReward);
        assertEq(app.balanceOf(ALICE), aliceReward);
    }

    function testCannotClaimTwice() public {
        // Setup same as testMerkleRewards
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        vm.prank(ALICE);
        referrals.registerReferralCode(aliceCode);

        uint256 aliceReward = 100e18;
        bytes32[] memory aliceProof = new bytes32[](1);
        aliceProof[0] = keccak256(abi.encodePacked("dummy proof"));

        bytes32 aliceLeaf = keccak256(abi.encodePacked(ALICE, aliceReward));
        bytes32 merkleRoot = keccak256(abi.encodePacked(aliceLeaf, aliceProof[0]));

        vm.startPrank(MERKLE_SERVER);
        deal(address(app), MERKLE_SERVER, aliceReward);
        app.approve(address(referrals), aliceReward);
        referrals.addMerkleRoot(merkleRoot, aliceReward);
        vm.stopPrank();

        // First claim succeeds
        vm.startPrank(ALICE);
        IAppReferrals.ClaimRewardsInput[] memory inputs = new IAppReferrals.ClaimRewardsInput[](1);
        inputs[0] =
            IAppReferrals.ClaimRewardsInput({root: merkleRoot, user: ALICE, amount: aliceReward, proofs: aliceProof});
        referrals.claimRewards(inputs);

        // Second claim should fail
        vm.expectRevert("Rewards already claimed");
        referrals.claimRewards(inputs);
        vm.stopPrank();
    }

    function testCannotExceedMerkleRootAmount() public {
        uint256 totalRewards = 100e18;
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked("dummy proof"));

        bytes32 leaf = keccak256(abi.encodePacked(ALICE, totalRewards + 1));
        bytes32 merkleRoot = keccak256(abi.encodePacked(leaf, proof[0]));

        vm.startPrank(MERKLE_SERVER);
        deal(address(app), MERKLE_SERVER, totalRewards);
        app.approve(address(referrals), totalRewards);
        referrals.addMerkleRoot(merkleRoot, totalRewards);
        vm.stopPrank();

        vm.startPrank(ALICE);
        IAppReferrals.ClaimRewardsInput[] memory inputs = new IAppReferrals.ClaimRewardsInput[](1);
        inputs[0] =
            IAppReferrals.ClaimRewardsInput({root: merkleRoot, user: ALICE, amount: totalRewards + 1, proofs: proof});

        vm.expectRevert("Not enough rewards to claim");
        referrals.claimRewards(inputs);
        vm.stopPrank();
    }

    function testBondWithReferral() public {
        // Alice generates a referral code
        vm.startPrank(ALICE);
        bytes8 aliceCode = bytes8(bytes20(ALICE));
        referrals.registerReferralCode(aliceCode);
        vm.stopPrank();

        // Create a bond
        vm.startPrank(owner);
        uint256 bondId = bondDepository.create(
            mockQuoteToken,
            1000e18, // capacity
            2e18, // initial price
            1e18, // final price
            7 days // duration
        );
        vm.stopPrank();

        // Bob uses Alice's referral code to buy bond
        vm.startPrank(BOB);
        uint256 bondAmount = 100e18;
        deal(address(mockQuoteToken), BOB, bondAmount);
        mockQuoteToken.approve(address(referrals), bondAmount);

        vm.expectEmit(true, true, false, true);
        emit ReferralRegistered(BOB, ALICE, aliceCode);
        referrals.bondWithReferral(bondId, bondAmount, 2e18, 0, aliceCode);
        vm.stopPrank();

        // Verify referral is tracked
        address[] memory aliceReferrals = referrals.getReferrals(ALICE);
        assertEq(aliceReferrals.length, 1);
        assertEq(aliceReferrals[0], BOB);
        assertEq(referrals.trackedReferrals(BOB), ALICE);
    }
}
