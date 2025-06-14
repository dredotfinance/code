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
    function testInitialisation() public {
        // The vault should report the correct underlying asset (RZR)
        assertEq(vault.asset(), address(app));
        // A staking position must have been created and owned by the vault
        uint256 id = vault.tokenId();
        assertGt(id, 0);
        assertEq(staking.ownerOf(id), address(vault));
    }

    /// @notice Position created via initialisePosition should hold staked amount > 0
    function testInitialPositionAmount() public view {
        IAppStaking.Position memory pos = staking.positions(vault.tokenId());
        assertGt(pos.amount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                   HARVEST
    //////////////////////////////////////////////////////////////*/

    function testHarvest() public {
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
    function testDeposit() public {
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
    function testWithdrawReverts() public {
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
    function testPreviewDepositMatchesDeposit() public {
        uint256 assets = 10 ether;
        _prepareUser(assets);

        uint256 expectedShares = vault.previewDeposit(assets);
        uint256 returnedShares = vault.deposit(assets, user1);
        assertEq(returnedShares, expectedShares, "previewDeposit mismatch");
        vm.stopPrank();
    }

    /// Mint is expected to revert in the current implementation because supply is zero and required assets are prohibitive
    function testMintReverts() public {
        _prepareUser(1 ether); // approval setup
        vm.expectRevert();
        vault.mint(1 ether, user1);
        vm.stopPrank();
    }

    /// convertToShares should be non-increasing (assets returned after round trip <= original)
    function testConvertAssetsMonotonic() public view {
        uint256 assets = 7 ether;
        uint256 shares = vault.convertToShares(assets);
        uint256 assetsRoundtrip = vault.convertToAssets(shares);
        assertLe(assetsRoundtrip, assets);
    }

    /// convertToAssets and convertToShares round-trip for shares input
    function testConvertRoundtripSharesAssets() public view {
        uint256 shares = 4 ether;
        uint256 assets = vault.convertToAssets(shares);
        uint256 sharesRoundtrip = vault.convertToShares(assets);
        assertApproxEqAbs(sharesRoundtrip, shares, 1e9);
    }

    /// maxDeposit and maxMint should return uint256 max
    function testMaxDepositMintUnlimited() public view {
        assertEq(vault.maxDeposit(user1), type(uint256).max);
        assertEq(vault.maxMint(user1), type(uint256).max);
    }

    /// maxWithdraw and maxRedeem reflect user balance
    function testMaxWithdrawRedeemMatchesBalance() public {
        uint256 assets = 12 ether;
        _prepareUser(assets);
        uint256 shares = vault.deposit(assets, user1);
        vm.stopPrank();

        uint256 maxWithdraw = vault.maxWithdraw(user1);
        uint256 maxRedeem = vault.maxRedeem(user1);
        assertEq(maxRedeem, shares);
        assertApproxEqAbs(maxWithdraw, vault.convertToAssets(shares), 1e9);
    }
}
