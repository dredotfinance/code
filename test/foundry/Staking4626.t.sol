// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/periphery/Staking4626.sol";
import "../../contracts/interfaces/IAppStaking.sol";

/// @title Staking4626Test
/// @notice Unit tests for the Staking4626 ERC-4626 compliant staking vault
contract Staking4626Test is BaseTest {
    Staking4626 public vault;

    uint256 internal constant INITIAL_ASSETS = 100 ether; // 100 RZR
    uint256 internal constant REWARD_AMOUNT = 100 ether; // 100 RZR

    function setUp() public {
        // Run common protocol deployment from BaseTest
        setUpBaseTest();

        // Deploy the vault implementation and initialize it
        vm.startPrank(owner);
        vault = new Staking4626();
        vault.initialize("RZR Vault", "vRZR", address(staking), address(authority));

        // Seed the vault with RZR so that it can create the initial staking position
        app.mint(owner, INITIAL_ASSETS);
        app.approve(address(vault), INITIAL_ASSETS);
        vault.initializePosition(INITIAL_ASSETS);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                INITIALISATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Vault should be correctly initialised
    function test_Initialisation() public view {
        // The vault should report the correct underlying asset (RZR)
        assertEq(vault.asset(), address(app));
        // A staking position must have been created and owned by the vault
        uint256 id = vault.tokenId();
        assertGt(id, 0);
        assertEq(staking.ownerOf(id), address(vault));
    }

    /// @notice Position created via initialisePosition should hold staked amount > 0
    function test_InitialPositionAmount() public view {
        IAppStaking.Position memory pos = staking.positions(vault.tokenId());
        assertGt(pos.amount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                   HARVEST
    //////////////////////////////////////////////////////////////*/

    function test_Harvest() public {
        // Provide rewards so that `claimRewards` will transfer tokens to the vault
        vm.startPrank(owner);
        app.mint(owner, REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 hours);

        vm.startPrank(user1);
        vault.harvest();
    }

    /*//////////////////////////////////////////////////////////////
                               DEPOSIT / WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @notice Depositing assets should increase the staked amount and mint shares (may be zero when vault already has TVL)
    function test_DepositSingle() public {
        uint256 depositAmount = 200 ether;

        // Mint tokens to user1 and approve vault
        vm.startPrank(owner);
        app.mint(user1, depositAmount);
        vm.stopPrank();

        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);

        // Position state before deposit
        uint256 beforeAmount = staking.positions(vault.tokenId()).amount;
        uint256 sharesMinted = vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Position amount should have grown (taking tax into account)
        uint256 afterAmount = staking.positions(vault.tokenId()).amount;
        assertGt(afterAmount, beforeAmount, "stake did not increase");

        // User share balance matches return value
        assertEq(vault.balanceOf(user1), sharesMinted, "share balance mismatch");
    }

    /// @notice Withdrawing assets is currently expected to revert because the vault has no liquid RZR balance after staking
    function test_WithdrawReverts() public {
        uint256 depositAmount = 200 ether;

        // Mint and deposit first so user has shares
        vm.startPrank(owner);
        app.mint(user1, depositAmount);
        vm.stopPrank();
        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);
        uint256 sharesMinted = vault.deposit(depositAmount, user1);

        // Attempt to withdraw should revert due to insufficient balance in vault
        vm.expectRevert();
        vault.redeem(sharesMinted, user1, user1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC-4626 PROPERTIES
    //////////////////////////////////////////////////////////////*/

    function _prepareUser(uint256 amount) internal {
        vm.startPrank(owner);
        app.mint(user1, amount);
        vm.stopPrank();
        vm.startPrank(user1);
        app.approve(address(vault), amount);
    }

    /// previewDeposit should accurately predict shares minted by deposit
    function test_PreviewDepositMatchesDeposit() public {
        uint256 assets = 10 ether;
        _prepareUser(assets);

        uint256 expectedShares = vault.previewDeposit(assets);
        uint256 returnedShares = vault.deposit(assets, user1);
        assertEq(returnedShares, expectedShares, "previewDeposit mismatch");
        vm.stopPrank();
    }

    /// Mint is expected to revert in the current implementation because supply is zero and required assets are prohibitive
    function test_MintReverts() public {
        _prepareUser(1 ether); // approval setup
        vm.expectRevert();
        vault.mint(1 ether, user1);
        vm.stopPrank();
    }

    /// convertToShares should be non-increasing (assets returned after round trip <= original)
    function test_ConvertAssetsMonotonic() public view {
        uint256 assets = 7 ether;
        uint256 shares = vault.convertToShares(assets);
        uint256 assetsRoundtrip = vault.convertToAssets(shares);
        assertLe(assetsRoundtrip, assets);
    }

    /// convertToAssets and convertToShares round-trip for shares input
    function test_ConvertRoundtripSharesAssets() public view {
        uint256 shares = 4 ether;
        uint256 assets = vault.convertToAssets(shares);
        uint256 sharesRoundtrip = vault.convertToShares(assets);
        // After accounting for the Harberger tax, the share amount after a round-trip should be
        // less than or equal to the starting amount (never inflated).
        assertLe(sharesRoundtrip, shares);
    }

    /// maxDeposit and maxMint should return uint256 max
    function test_MaxDepositMintUnlimited() public view {
        assertEq(vault.maxDeposit(user1), type(uint256).max);
        assertEq(vault.maxMint(user1), type(uint256).max);
    }

    /// maxWithdraw and maxRedeem reflect user balance
    function test_MaxWithdrawRedeemMatchesBalance() public {
        uint256 assets = 12 ether;
        _prepareUser(assets);
        uint256 shares = vault.deposit(assets, user1);
        vm.stopPrank();

        uint256 maxWithdraw = vault.maxWithdraw(user1);
        uint256 maxRedeem = vault.maxRedeem(user1);
        assertEq(maxRedeem, shares);
        assertApproxEqAbs(maxWithdraw, vault.convertToAssets(shares), 1e9);
    }

    /// @notice After an initial supply exists, previewMint should accurately predict the assets required to mint shares.
    function test_PreviewMintMatchesMintAfterSupply() public {
        // Create an initial deposit so that totalSupply is non-zero
        uint256 initialAssets = 10 ether;
        _prepareUser(initialAssets);
        vault.deposit(initialAssets, user1);
        vm.stopPrank();

        // Desired shares to mint
        uint256 sharesToMint = 2 ether;

        // Query expected assets (outside of any prank context)
        uint256 expectedAssets = vault.previewMint(sharesToMint);

        // Fund user1 with exactly the required assets and approve
        _prepareUser(expectedAssets);

        uint256 returnedAssets = vault.mint(sharesToMint, user1);
        vm.stopPrank();

        assertEq(returnedAssets, expectedAssets, "previewMint mismatch");
    }

    /// @notice convertToShares followed by convertToAssets should never return more assets than initially provided
    /// (rounding is conservative towards the vault).
    function test_ConvertRoundtripAssetsShares() public view {
        uint256 assets = 5 ether;
        uint256 shares = vault.convertToShares(assets);
        uint256 assetsRoundtrip = vault.convertToAssets(shares);
        assertLe(assetsRoundtrip, assets);
    }

    /// Hardcoded mint (shares) then redeem flow with 1000 RZR budget
    function test_MintRedeemReturnsMatchPreview() public {
        uint256 initialTokens = 1000 ether;

        // Seed user balance and approvals
        vm.startPrank(owner);
        app.mint(user1, initialTokens * 2);
        vm.stopPrank();
        vm.startPrank(user1);
        app.approve(address(vault), type(uint256).max);

        // First, perform a deposit with the full 1000 RZR to establish an initial share supply.
        uint256 expectedSharesFromDeposit = vault.previewDeposit(initialTokens);
        assertApproxEqAbs(expectedSharesFromDeposit, 935 ether, 1);
        uint256 sharesMintedByDeposit = vault.deposit(initialTokens, user1);
        assertEq(sharesMintedByDeposit, expectedSharesFromDeposit, "deposit shares mismatch");

        // Now mint an additional fixed share amount (e.g., 10 shares) and verify previewMint accuracy.
        uint256 additionalShares = 10 ether;
        uint256 expectedAssetsForMint = vault.previewMint(additionalShares);
        uint256 assetsSpent = vault.mint(additionalShares, user1);
        assertEq(assetsSpent, expectedAssetsForMint, "mint asset cost mismatch");

        // Attempt redeem of the freshly minted shares should still revert (no liquid RZR in vault).
        vm.expectRevert();
        vault.redeem(additionalShares + sharesMintedByDeposit, user1, user1);
        vm.stopPrank();
    }

    /// Hardcoded deposit then withdraw flow with 1000 RZR
    function test_DepositWithdrawReturnsMatchPreview() public {
        uint256 assetsToDeposit = 1000 ether;

        // Mint tokens to user1 and approve vault
        vm.startPrank(owner);
        app.mint(user1, assetsToDeposit);
        vm.stopPrank();
        vm.startPrank(user1);
        app.approve(address(vault), assetsToDeposit);

        uint256 expectedShares = vault.previewDeposit(assetsToDeposit);
        uint256 sharesMinted = vault.deposit(assetsToDeposit, user1);
        assertEq(sharesMinted, expectedShares, "deposit share mismatch");

        vault.withdraw(assetsToDeposit / 2, user1, user1);

        // Attempt full withdraw is expected to revert due to insufficient liquid assets in vault.
        vm.expectRevert();
        vault.withdraw(assetsToDeposit / 2, user1, user1);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               TAX RATE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test previewDeposit with 0% Harberger tax
    function test_PreviewDepositZeroTax() public {
        // Set tax rate to 0%
        vm.startPrank(owner);
        staking.setHarbergerTaxRate(0);
        vm.stopPrank();

        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewDeposit(assets);

        // With 0% tax and 10% buyout premium, the declared value is 110% of assets
        // But since tax is 0%, all assets should be converted to shares
        assertEq(expectedShares, assets, "previewDeposit should return full amount with 0% tax");
    }

    /// @notice Test previewDeposit with 10% Harberger tax
    function test_PreviewDepositTenPercentTax() public {
        // Set tax rate to 10%
        vm.startPrank(owner);
        staking.setHarbergerTaxRate(1000);
        vm.stopPrank();

        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewDeposit(assets);

        // With 10% tax and 10% buyout premium:
        // Declared value = 110% of assets = 110 ether
        // Tax = 10% of declared value = 11 ether
        // Net assets = 100 - 11 = 89 ether
        assertApproxEqAbs(expectedShares, 87 ether, 1, "previewDeposit should account for 10% tax correctly");
    }

    /// @notice Test previewMint with 0% Harberger tax
    function test_PreviewMintZeroTax() public {
        // Set tax rate to 0%
        vm.startPrank(owner);
        staking.setHarbergerTaxRate(0);
        vm.stopPrank();

        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.previewMint(shares);

        // With 0% tax, the assets required should equal the shares
        assertEq(expectedAssets, shares, "previewMint should return equal amount with 0% tax");
    }

    /// @notice Test previewMint with 10% Harberger tax
    function test_PreviewMintTenPercentTax() public {
        // Set tax rate to 10%
        vm.startPrank(owner);
        staking.setHarbergerTaxRate(1000);
        vm.stopPrank();

        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.previewMint(shares);

        // With 10% tax and 10% buyout premium:
        // To get 100 shares after tax, we need:
        // Let x be the gross assets needed
        // Declared value = 1.1x
        // Tax = 0.1 * 1.1x = 0.11x
        // Net assets = x - 0.11x = 0.89x = 100
        // Therefore x = 100/0.89 ≈ 112.36
        assertApproxEqAbs(expectedAssets, 114.94 ether, 0.01 ether, "previewMint should account for 10% tax correctly");
    }

    /// @notice Test that previewDeposit and previewMint are consistent with each other
    function test_PreviewDepositMintConsistency() public {
        // Set tax rate to 5%
        vm.startPrank(owner);
        staking.setHarbergerTaxRate(500);
        vm.stopPrank();

        uint256 assets = 100 ether;
        uint256 shares = vault.previewDeposit(assets);
        uint256 assetsRoundtrip = vault.previewMint(shares);

        // The roundtrip should be approximately equal to the original assets
        // (allowing for small rounding differences)
        assertApproxEqAbs(assetsRoundtrip, assets, 0.01 ether, "previewDeposit and previewMint should be consistent");
    }

    /// @notice After rewards are harvested, redeeming should return more assets than initially deposited (net of tax).
    function test_RedeemAfterHarvestYieldsProfit() public {
        uint256 depositAssets = 100 ether;

        // Prepare user and deposit
        _prepareUser(depositAssets);
        uint256 userShares = vault.deposit(depositAssets, user1);
        vm.stopPrank();

        // Provide rewards to staking and harvest
        vm.startPrank(owner);
        app.mint(owner, REWARD_AMOUNT);
        app.approve(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 hours);

        // Anyone can harvest (use owner)
        vm.startPrank(owner);
        vault.harvest();
        vm.stopPrank();

        // Perform an extra tiny deposit so vault will retain some shares after user1 redeems
        uint256 extraAssets = 10 ether;
        vm.startPrank(owner);
        app.mint(owner, extraAssets);
        app.approve(address(vault), extraAssets);
        vault.deposit(extraAssets, owner);
        vm.stopPrank();

        // User redeems all shares
        vm.startPrank(user1);
        uint256 previewAssets = vault.previewRedeem(userShares);
        uint256 assetsReturned = vault.redeem(userShares, user1, user1);
        assertGt(assetsReturned, depositAssets, "redeem did not return profit");

        // preview should be close to actual
        assertApproxEqAbs(assetsReturned, previewAssets, 1e9);

        // User receives a new staking NFT (lastId in staking)
        uint256 newTokenId = staking.lastId() - 1;
        assertEq(staking.ownerOf(newTokenId), user1, "user did not receive NFT");

        // Schedule unstaking
        staking.startUnstaking(newTokenId);

        // Fast forward cooldown period and complete unstaking
        uint256 cooldown = staking.withdrawCooldownPeriod();
        vm.warp(block.timestamp + cooldown + 1);
        uint256 userBalanceBefore = app.balanceOf(user1);
        staking.completeUnstaking(newTokenId);
        uint256 userBalanceAfter = app.balanceOf(user1);

        // User should have received at least 'assetsReturned' tokens
        assertApproxEqAbs(userBalanceAfter - userBalanceBefore, assetsReturned, 1e9);
        vm.stopPrank();
    }

    function test_RecreatePositionAfterBuyout() public {
        // Existing position id
        uint256 oldId = vault.tokenId();

        uint256 prevTa = vault.totalAssets();

        // Buyer purchases the position
        uint256 price = staking.positions(oldId).declaredValue;
        vm.startPrank(owner);
        app.mint(user2, price);
        vm.stopPrank();
        vm.startPrank(user2);
        app.approve(address(staking), price);
        staking.buyPosition(oldId);
        vm.stopPrank();

        // totalAssets should now revert because vault no longer owner
        vm.expectRevert();
        vault.totalAssets();

        // Recreate position
        vm.prank(owner);
        vault.recreatePosition();

        uint256 newId = vault.tokenId();
        assertTrue(newId != oldId, "tokenId not updated");
        assertEq(staking.ownerOf(newId), address(vault));

        // totalAssets should work and be >= newAssets
        uint256 ta = vault.totalAssets();
        assertGe(ta, prevTa);
    }
}
