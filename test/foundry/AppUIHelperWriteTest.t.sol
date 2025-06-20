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
    address public ODOS = makeAddr("odos");

    // Mock data
    bytes8 public REFERRAL_CODE = bytes8(bytes20(ALICE));

    function setUp() public {
        // Setup base contracts
        setUpBaseTest();

        // Setup referrals contract
        referrals = new AppReferrals();
        referrals.initialize(
            address(bondDepository), address(staking), address(app), address(treasury), address(authority), address(0)
        );

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
        vm.label(ODOS, "ODOS");
        vm.label(address(uiHelper), "UI_HELPER");
        vm.label(address(referrals), "REFERRALS");
    }

    function test_Constructor() public view {
        assertEq(address(uiHelper.staking()), address(staking));
        assertEq(address(uiHelper.bondDepository()), address(bondDepository));
        assertEq(address(uiHelper.treasury()), address(treasury));
        assertEq(address(uiHelper.appToken()), address(app));
        assertEq(address(uiHelper.stakingToken()), address(0));
        assertEq(address(uiHelper.appOracle()), address(appOracle));
        assertEq(uiHelper.odos(), ODOS);
        assertEq(address(uiHelper.referrals()), address(referrals));
    }

    function test_ClaimAllRewards() public {
        // Setup: Alice has a staking position with rewards
        vm.startPrank(ALICE);
        uint256 stakeAmount = 1000e18;
        deal(address(app), ALICE, stakeAmount);
        app.approve(address(staking), stakeAmount);
        staking.createPosition(ALICE, stakeAmount, stakeAmount, 0);
        vm.stopPrank();

        // Simulate some rewards
        vm.startPrank(owner);
        uint256 rewardAmount = 100e18;
        deal(address(app), address(staking), rewardAmount);
        vm.stopPrank();

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

        // Setup zap parameters
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

        // Setup zap parameters
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(mockQuoteToken),
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
        deal(address(mockQuoteToken), BOB, 100e18);
        mockQuoteToken.approve(address(uiHelper), 100e18);

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

        // Setup zap parameters
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(mockQuoteToken),
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
        deal(address(mockQuoteToken), BOB, 100e18);
        mockQuoteToken.approve(address(uiHelper), 100e18);

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

        (uint256 tokenId,,,) = uiHelper.zapAndStake{value: 1e18}(odosParams, stakeParams);
        vm.stopPrank();

        // Verify staking position was created
        assertGt(tokenId, 0, "Should receive token ID");
    }

    function test_ZapAndBuyBond_InvalidETHAmount() public {
        // Setup zap parameters with ETH
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(0), // ETH
            tokenAmountIn: 1e18,
            odosTokenIn: address(mockQuoteToken),
            odosTokenAmountIn: 100e18,
            odosData: ""
        });

        AppUIHelperWrite.BondParams memory bondParams = AppUIHelperWrite.BondParams({
            id: 1,
            amount: 100e18,
            maxPrice: 2e18,
            minPayout: 0,
            referralCode: REFERRAL_CODE
        });

        // Bob tries to zap with wrong ETH amount
        vm.startPrank(BOB);
        deal(BOB, 2e18);
        vm.expectRevert("Invalid ETH amount");
        uiHelper.zapAndBuyBond{value: 0.5e18}(odosParams, bondParams);
        vm.stopPrank();
    }

    function test_ZapAndStake_InvalidETHAmount() public {
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

        // Bob tries to zap with wrong ETH amount
        vm.startPrank(BOB);
        deal(BOB, 2e18);
        vm.expectRevert("Invalid ETH amount");
        uiHelper.zapAndStake{value: 0.5e18}(odosParams, stakeParams);
        vm.stopPrank();
    }

    function test_ZapAndBuyBond_OdosCallFailed() public {
        // Setup zap parameters with invalid odos data
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(mockQuoteToken),
            tokenAmountIn: 100e18,
            odosTokenIn: address(mockQuoteToken),
            odosTokenAmountIn: 100e18,
            odosData: hex"12345678" // Invalid data
        });

        AppUIHelperWrite.BondParams memory bondParams = AppUIHelperWrite.BondParams({
            id: 1,
            amount: 100e18,
            maxPrice: 2e18,
            minPayout: 0,
            referralCode: REFERRAL_CODE
        });

        // Bob tries to zap with invalid odos data
        vm.startPrank(BOB);
        deal(address(mockQuoteToken), BOB, 100e18);
        mockQuoteToken.approve(address(uiHelper), 100e18);
        vm.expectRevert("Odos call failed");
        uiHelper.zapAndBuyBond(odosParams, bondParams);
        vm.stopPrank();
    }

    function test_ZapAndStake_OdosCallFailed() public {
        // Setup zap parameters with invalid odos data
        AppUIHelperWrite.OdosParams memory odosParams = AppUIHelperWrite.OdosParams({
            tokenIn: address(mockQuoteToken),
            tokenAmountIn: 100e18,
            odosTokenIn: address(app),
            odosTokenAmountIn: 100e18,
            odosData: hex"12345678" // Invalid data
        });

        AppUIHelperWrite.StakeParams memory stakeParams = AppUIHelperWrite.StakeParams({
            amountDeclared: 100e18,
            amountDeclaredAsPercentage: 0,
            referralCode: REFERRAL_CODE
        });

        // Bob tries to zap with invalid odos data
        vm.startPrank(BOB);
        deal(address(mockQuoteToken), BOB, 100e18);
        mockQuoteToken.approve(address(uiHelper), 100e18);
        vm.expectRevert("Odos call failed");
        uiHelper.zapAndStake(odosParams, stakeParams);
        vm.stopPrank();
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
}
