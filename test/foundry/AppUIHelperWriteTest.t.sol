// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/periphery/AppUIHelperWrite.sol";
import "../../contracts/core/AppReferrals.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AppUIHelperWriteTest is BaseTest {
    AppUIHelperWrite public uiHelper;
    AppReferrals public referrals;

    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");
    address public CHARLIE = makeAddr("charlie");
    address public ODOS = makeAddr("odos");

    // Mock data
    bytes8 public REFERRAL_CODE = bytes8(bytes20(ALICE));

    function setUp() public {
        // Setup base contracts
        setUpBaseTest();

        // Setup referrals contract
        referrals = new AppReferrals();
        referrals.initialize(
            address(bondDepository),
            address(staking),
            address(app),
            address(treasury),
            address(staking4626),
            address(authority)
        );

        vm.startPrank(owner);
        referrals.whitelist(ALICE);
        referrals.whitelist(BOB);
        referrals.whitelist(CHARLIE);
        referrals.whitelist(ODOS);
        vm.stopPrank();

        // Setup UI Helper
        uiHelper = new AppUIHelperWrite(
            address(staking),
            address(bondDepository),
            address(treasury),
            address(app),
            address(staking),
            address(rebaseController),
            address(appOracle),
            address(0),
            ODOS,
            address(referrals)
        );

        // Set up permissions
        vm.startPrank(owner);
        authority.addPolicy(address(uiHelper));
        vm.stopPrank();

        // Label addresses for better trace output
        vm.label(ALICE, "ALICE");
        vm.label(BOB, "BOB");
        vm.label(CHARLIE, "CHARLIE");
        vm.label(ODOS, "ODOS");
        vm.label(address(uiHelper), "UI_HELPER");
        vm.label(address(referrals), "REFERRALS");
    }

    function test_Constructor() public view {
        assertEq(address(uiHelper.staking()), address(staking));
        assertEq(address(uiHelper.bondDepository()), address(bondDepository));
        assertEq(address(uiHelper.treasury()), address(treasury));
        assertEq(address(uiHelper.appToken()), address(app));
        assertEq(address(uiHelper.appOracle()), address(appOracle));
        assertEq(uiHelper.odos(), ODOS);
        assertEq(address(uiHelper.referrals()), address(referrals));
    }

    function test_ClaimAllRewards() public {
        // Setup: Alice has a staking position
        vm.startPrank(ALICE);
        uint256 stakeAmount = 1000e18;
        deal(address(app), ALICE, stakeAmount);
        app.approve(address(staking), stakeAmount);
        staking.createPosition(ALICE, stakeAmount, stakeAmount, 0);
        vm.stopPrank();

        // Notify rewards
        uint256 rewardAmount = 100e18;
        deal(address(app), address(owner), rewardAmount);
        vm.prank(owner);
        app.approve(address(staking), rewardAmount);
        vm.prank(owner);
        staking.notifyRewardAmount(rewardAmount);

        // Advance time to accrue rewards
        vm.warp(block.timestamp + 1 days);

        // Alice claims all rewards through UI helper
        vm.startPrank(ALICE);
        uint256 claimedAmount = uiHelper.claimAllRewards(ALICE);
        vm.stopPrank();

        // Verify rewards were claimed
        assertGt(claimedAmount, 0, "Should have claimed rewards");
        assertGt(app.balanceOf(ALICE), 0, "Alice should have received rewards");
    }

    function test_ClaimAllRewards_NoPositions() public {
        // Bob has no staking positions
        vm.startPrank(BOB);
        uint256 claimedAmount = uiHelper.claimAllRewards(BOB);
        vm.stopPrank();

        assertEq(claimedAmount, 0, "Should claim 0 rewards when no positions");
    }

    function test_ZapAndBuyBond() public {
        // Setup: Alice registers a referral code
        vm.startPrank(ALICE);
        referrals.registerReferralCode(REFERRAL_CODE);
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

        // Setup zap parameters - use the same token for input and output to avoid complex swaps
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(mockQuoteToken),
            tokenAmountIn: 100e18,
            odosTokenIn: address(mockQuoteToken),
            odosTokenAmountIn: 100e18,
            odosData: ""
        });

        AppUIHelperWrite.BondParams memory bondParams = AppUIHelperWrite.BondParams({
            id: bondId,
            amount: 100e18,
            maxPrice: 2e18,
            minPayout: 0,
            referralCode: REFERRAL_CODE
        });

        // Bob zaps and buys bond
        vm.startPrank(BOB);
        deal(address(mockQuoteToken), BOB, 100e18);
        mockQuoteToken.approve(address(uiHelper), 100e18);

        (uint256 payout, uint256 tokenId) = uiHelper.zapAndBuyBond(odosParams, bondParams);
        vm.stopPrank();

        // Verify bond was created
        assertGt(payout, 0, "Should receive payout");
        assertGt(tokenId, 0, "Should receive token ID");
    }

    function test_ZapAndBuyBond_WithETH() public {
        // Setup: Alice registers a referral code
        vm.startPrank(ALICE);
        referrals.registerReferralCode(REFERRAL_CODE);
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

        // Setup zap parameters with ETH
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(0), // ETH
            tokenAmountIn: 1e18,
            odosTokenIn: address(mockQuoteToken),
            odosTokenAmountIn: 100e18,
            odosData: ""
        });

        AppUIHelperWrite.BondParams memory bondParams = AppUIHelperWrite.BondParams({
            id: bondId,
            amount: 100e18,
            maxPrice: 2e18,
            minPayout: 0,
            referralCode: REFERRAL_CODE
        });

        // Bob zaps and buys bond with ETH
        vm.startPrank(BOB);
        deal(BOB, 2e18); // Give Bob some ETH

        // Simulate zap output: give the UI helper the mockQuoteToken it needs
        deal(address(mockQuoteToken), address(uiHelper), 100e18);

        (uint256 payout, uint256 tokenId) = uiHelper.zapAndBuyBond{value: 1e18}(odosParams, bondParams);
        vm.stopPrank();

        // Verify bond was created
        assertGt(payout, 0, "Should receive payout");
        assertGt(tokenId, 0, "Should receive token ID");
    }

    function test_ZapAndStake() public {
        // Setup: Alice registers a referral code
        vm.startPrank(ALICE);
        referrals.registerReferralCode(REFERRAL_CODE);
        vm.stopPrank();

        // Setup zap parameters - use the same token for input and output to avoid complex swaps
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(app),
            tokenAmountIn: 100e18,
            odosTokenIn: address(app),
            odosTokenAmountIn: 100e18,
            odosData: ""
        });

        AppUIHelperWrite.StakeParams memory stakeParams = AppUIHelperWrite.StakeParams({
            amountDeclared: 100e18,
            amountDeclaredAsPercentage: 0,
            referralCode: REFERRAL_CODE
        });

        // Bob zaps and stakes
        vm.startPrank(BOB);
        deal(address(app), BOB, 100e18);
        app.approve(address(uiHelper), 100e18);

        (uint256 tokenId,,, uint256 amountDeclared) = uiHelper.zapAndStake(odosParams, stakeParams);
        vm.stopPrank();

        // Verify staking position was created
        assertGt(tokenId, 0, "Should receive token ID");
        assertEq(amountDeclared, 100e18, "Amount declared should match");
    }

    function test_ZapAndStakeAsPercentage() public {
        // Setup: Alice registers a referral code
        vm.startPrank(ALICE);
        referrals.registerReferralCode(REFERRAL_CODE);
        vm.stopPrank();

        // Setup zap parameters - use the same token for input and output to avoid complex swaps
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(app),
            tokenAmountIn: 100e18,
            odosTokenIn: address(app),
            odosTokenAmountIn: 100e18,
            odosData: ""
        });

        AppUIHelperWrite.StakeParams memory stakeParams = AppUIHelperWrite.StakeParams({
            amountDeclared: 0,
            amountDeclaredAsPercentage: 0.5e18, // 50%
            referralCode: REFERRAL_CODE
        });

        // Bob zaps and stakes as percentage
        vm.startPrank(BOB);
        deal(address(app), BOB, 100e18);
        app.approve(address(uiHelper), 100e18);

        (uint256 tokenId,,, uint256 amountDeclared) = uiHelper.zapAndStakeAsPercentage(odosParams, stakeParams);
        vm.stopPrank();

        // Verify staking position was created
        assertGt(tokenId, 0, "Should receive token ID");
        assertGt(amountDeclared, 0, "Amount declared should be calculated from percentage");
    }

    function test_ZapAndStake_WithETH() public {
        // Setup: Alice registers a referral code
        vm.startPrank(ALICE);
        referrals.registerReferralCode(REFERRAL_CODE);
        vm.stopPrank();

        // Setup zap parameters with ETH
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(0), // ETH
            tokenAmountIn: 1e18,
            odosTokenIn: address(app),
            odosTokenAmountIn: 100e18,
            odosData: ""
        });

        AppUIHelperWrite.StakeParams memory stakeParams = AppUIHelperWrite.StakeParams({
            amountDeclared: 100e18,
            amountDeclaredAsPercentage: 0,
            referralCode: REFERRAL_CODE
        });

        // Bob zaps and stakes with ETH
        vm.startPrank(BOB);
        deal(BOB, 2e18); // Give Bob some ETH

        // Simulate zap output: give the UI helper the app tokens it needs
        deal(address(app), address(uiHelper), 100e18);

        (uint256 tokenId,,,) = uiHelper.zapAndStake{value: 1e18}(odosParams, stakeParams);
        vm.stopPrank();

        // Verify staking position was created
        assertGt(tokenId, 0, "Should receive token ID");
    }

    function test_Receive() public {
        // Test that the contract can receive ETH
        vm.deal(ALICE, 1e18);
        vm.startPrank(ALICE);

        // Send ETH to the contract
        (bool success,) = address(uiHelper).call{value: 0.5e18}("");
        assertTrue(success, "Should be able to receive ETH");

        vm.stopPrank();
    }

    function test_ZapIntoLST() public {
        // Setup: Alice registers a referral code
        vm.startPrank(ALICE);
        referrals.registerReferralCode(REFERRAL_CODE);
        vm.stopPrank();

        // Setup zap parameters - use the same token for input and output to avoid complex swaps
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(app),
            tokenAmountIn: 100e18,
            odosTokenIn: address(app),
            odosTokenAmountIn: 100e18,
            odosData: ""
        });

        bytes8 referralCode = REFERRAL_CODE;
        address destination = BOB;

        // Bob zaps into LST
        vm.startPrank(BOB);
        deal(address(app), BOB, 100e18);
        app.approve(address(uiHelper), 100e18);

        uint256 minted = uiHelper.zapIntoLST(odosParams, referralCode, destination);
        vm.stopPrank();

        // Verify LST deposit was successful
        assertGt(minted, 0, "Should receive minted shares");
    }

    function test_ZapIntoLST_WithETH() public {
        // Setup: Alice registers a referral code
        vm.startPrank(ALICE);
        referrals.registerReferralCode(REFERRAL_CODE);
        vm.stopPrank();

        // Setup zap parameters with ETH
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(0), // ETH
            tokenAmountIn: 1e18,
            odosTokenIn: address(app),
            odosTokenAmountIn: 100e18,
            odosData: ""
        });

        bytes8 referralCode = REFERRAL_CODE;
        address destination = BOB;

        // Bob zaps into LST with ETH
        vm.startPrank(BOB);
        deal(BOB, 2e18); // Give Bob some ETH

        // Simulate zap output: give the UI helper the app tokens it needs
        deal(address(app), address(uiHelper), 100e18);

        uint256 minted = uiHelper.zapIntoLST{value: 1e18}(odosParams, referralCode, destination);
        vm.stopPrank();

        // Verify LST deposit was successful
        assertGt(minted, 0, "Should receive minted shares");
    }

    function test_ZapIntoLST_InvalidReferralCode() public {
        // Setup zap parameters
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(app),
            tokenAmountIn: 100e18,
            odosTokenIn: address(app),
            odosTokenAmountIn: 100e18,
            odosData: ""
        });

        bytes8 invalidReferralCode = bytes8(bytes20(CHARLIE)); // Charlie hasn't registered this code
        address destination = BOB;

        // Bob zaps into LST with invalid referral code
        vm.startPrank(BOB);
        deal(address(app), BOB, 100e18);
        app.approve(address(uiHelper), 100e18);

        // Should not revert, but should not register referral
        uint256 minted = uiHelper.zapIntoLST(odosParams, invalidReferralCode, destination);
        vm.stopPrank();

        // Verify LST deposit was still successful
        assertGt(minted, 0, "Should receive minted shares even with invalid referral code");
    }
}
