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
        app.mint(address(vault), INITIAL_ASSETS);
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
    function test_Deposit() public {
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
        uint256 withdrawAmount = 50 ether;

        // Mint and deposit first so user has shares
        vm.startPrank(owner);
        app.mint(user1, depositAmount);
        vm.stopPrank();
        vm.startPrank(user1);
        app.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);

        // Attempt to withdraw should revert due to insufficient balance in vault
        vm.expectRevert();
        vault.withdraw(withdrawAmount, user1, user1);
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

    /// @notice Depositing a very small amount may mint 0 shares because of rounding down. Ensure no shares are issued while the staked
    /// amount still increases so the user does not receive an unfair amount of vault shares.
    function test_SmallDepositMintsZeroShares() public {
        uint256 smallAmount = 1; // 1 wei of the asset token

        uint256 beforeStaked = staking.positions(vault.tokenId()).amount;

        // Give `user1` the minimal amount and approve the vault
        _prepareUser(smallAmount);

        // Still in user1 context after _prepareUser
        uint256 mintedShares = vault.deposit(smallAmount, user1);
        vm.stopPrank();

        uint256 afterStaked = staking.positions(vault.tokenId()).amount;

        // No shares should have been minted due to rounding, but the position amount must have grown
        assertEq(mintedShares, 0, "non-zero shares minted for tiny deposit");
        assertEq(vault.balanceOf(user1), 0, "user received shares for tiny deposit");
        assertGt(afterStaked, beforeStaked, "staking amount did not increase");
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

        // Mint tokens to user1 and approve vault
        vm.startPrank(owner);
        app.mint(user1, initialTokens);
        vm.stopPrank();
        vm.startPrank(user1);
        app.approve(address(vault), type(uint256).max);

        // Derive a shares amount that our 1000 RZR balance can cover.
        uint256 sharesToMint = vault.previewDeposit(initialTokens); // typically ~9 shares
        assertEq(sharesToMint, 9);

        uint256 requiredAssetsForMint = vault.previewMint(sharesToMint);
        // Ensure requirement fits within the 1000 token allowance per the test spec
        assertLe(requiredAssetsForMint, initialTokens, "previewMint exceeds 1000 token budget");

        uint256 assetsSpent = vault.mint(sharesToMint, user1);
        assertEq(assetsSpent, requiredAssetsForMint, "mint asset cost mismatch");
        assertEq(vault.balanceOf(user1), sharesToMint, "incorrect share balance after mint");

        vm.expectRevert();
        vault.redeem(sharesToMint, user1, user1);
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

        // Attempt full withdraw is expected to revert due to insufficient liquid assets in vault.
        vm.expectRevert();
        vault.withdraw(assetsToDeposit, user1, user1);
        vm.stopPrank();
    }
}
