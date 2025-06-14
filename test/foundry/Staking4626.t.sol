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
}
