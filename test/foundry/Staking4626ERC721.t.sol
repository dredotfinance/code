// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/periphery/Staking4626.sol";
import "../../contracts/interfaces/IAppStaking.sol";

/// @title Staking4626ERC721Test
/// @notice Unit tests for the ERC721 receiver functionality of Staking4626
contract Staking4626ERC721Test is BaseTest {
// Staking4626 public vault;
// uint256 internal constant INITIAL_ASSETS = 100 ether; // 100 RZR

// function setUp() public {
//     // Run common protocol deployment from BaseTest
//     setUpBaseTest();

//     // Deploy the vault implementation and initialize it
//     vm.startPrank(owner);
//     vault = new Staking4626();
//     vault.initialize("RZR Vault", "vRZR", address(staking), address(authority));

//     // Seed the vault with RZR so that it can create the initial staking position
//     app.mint(owner, INITIAL_ASSETS);
//     app.approve(address(vault), INITIAL_ASSETS);
//     vault.initializePosition(INITIAL_ASSETS);
//     vm.stopPrank();
// }

// function test_OnERC721Received_ValidTransfer() public {
//     // Create a new staking position for user1
//     uint256 depositAmount = 50 ether;
//     vm.startPrank(owner);
//     app.mint(user1, depositAmount);
//     vm.stopPrank();

//     vm.startPrank(user1);
//     app.approve(address(staking), depositAmount);
//     (uint256 tokenId,) = staking.createPosition(user1, depositAmount, depositAmount * 11 / 10, 0);

//     // Approve the vault to transfer the NFT
//     staking.approve(address(vault), tokenId);

//     // Record balances before transfer
//     uint256 vaultSharesBefore = vault.balanceOf(user1);
//     uint256 vaultPositionAmountBefore = staking.positions(vault.tokenId()).amount;

//     vm.warp(block.timestamp + 1 days);

//     // Transfer the NFT to the vault
//     staking.safeTransferFrom(user1, address(vault), tokenId);
//     vm.stopPrank();

//     // Verify the NFT was merged and burnt
//     vm.expectRevert();
//     staking.ownerOf(tokenId);

//     // Verify shares were minted to user1
//     uint256 vaultSharesAfter = vault.balanceOf(user1);
//     assertGt(vaultSharesAfter, vaultSharesBefore, "No shares minted to user1");

//     // Verify the position was merged
//     uint256 vaultPositionAmountAfter = staking.positions(vault.tokenId()).amount;
//     assertGt(vaultPositionAmountAfter, vaultPositionAmountBefore, "Position not merged");
// }

// function test_OnERC721Received_RevertInvalidSender() public {
//     // Create a mock NFT contract that's not the staking contract
//     MockNFT mockNFT = new MockNFT();

//     // Try to transfer from mock NFT contract
//     vm.expectRevert("Unsupported NFT sender");
//     mockNFT.safeTransferFrom(address(this), address(vault), 1);
// }

// function test_OnERC721Received_RevertNoVaultPosition() public {
//     // Create a new vault without initializing a position
//     Staking4626 newVault = new Staking4626();
//     vm.startPrank(owner);
//     newVault.initialize("New Vault", "nvRZR", address(staking), address(authority));
//     vm.stopPrank();

//     // Create a staking position for user1
//     uint256 depositAmount = 50 ether;
//     vm.startPrank(owner);
//     app.mint(user1, depositAmount);
//     vm.stopPrank();

//     vm.startPrank(user1);
//     app.approve(address(staking), depositAmount);
//     (uint256 tokenId,) = staking.createPosition(user1, depositAmount, depositAmount * 11 / 10, 0);

//     // Try to transfer to new vault (which has no position)
//     staking.approve(address(newVault), tokenId);
//     vm.expectRevert("Already owner");
//     staking.safeTransferFrom(user1, address(newVault), tokenId);
//     vm.stopPrank();
// }

// function test_OnERC721Received_RevertPositionInCooldown() public {
//     // Create a staking position for user1
//     uint256 depositAmount = 50 ether;
//     vm.startPrank(owner);
//     app.mint(user1, depositAmount);
//     vm.stopPrank();

//     vm.startPrank(user1);
//     app.approve(address(staking), depositAmount);
//     (uint256 tokenId,) = staking.createPosition(user1, depositAmount, depositAmount * 11 / 10, 0);

//     // Start unstaking to put position in cooldown
//     staking.startUnstaking(tokenId);

//     // Try to transfer to vault
//     staking.approve(address(vault), tokenId);
//     vm.expectRevert("Position is in cooldown");
//     staking.safeTransferFrom(user1, address(vault), tokenId);
//     vm.stopPrank();
// }

// function test_OnERC721Received_RevertPositionLocked() public {
//     // Create a staking position for user1 with a longer lock period
//     uint256 depositAmount = 50 ether;
//     vm.startPrank(owner);
//     app.mint(user1, depositAmount);
//     vm.stopPrank();

//     vm.startPrank(user1);
//     app.approve(address(staking), depositAmount);
//     (uint256 tokenId,) =
//         staking.createPosition(user1, depositAmount, depositAmount * 11 / 10, block.timestamp + 1 days);

//     // Try to transfer to vault
//     staking.approve(address(vault), tokenId);
//     vm.expectRevert("Position is locked");
//     staking.safeTransferFrom(user1, address(vault), tokenId);
//     vm.stopPrank();
// }

// function test_OnERC721Received_IncreaseDeclaredValue() public {
//     // Create a staking position for user1 with lower declared value
//     uint256 depositAmount = 50 ether;
//     vm.startPrank(owner);
//     app.mint(user1, depositAmount);
//     vm.stopPrank();

//     vm.startPrank(user1);
//     app.approve(address(staking), depositAmount);
//     (uint256 tokenId,) = staking.createPosition(user1, depositAmount, depositAmount, 0);

//     // Approve the vault to transfer the NFT
//     staking.approve(address(vault), tokenId);

//     // Forward time to ensure position is unlocked
//     vm.warp(block.timestamp + 1 days);

//     // Transfer the NFT to the vault
//     staking.safeTransferFrom(user1, address(vault), tokenId);
//     vm.stopPrank();

//     // Verify the declared value was increased
//     IAppStaking.Position memory position = staking.positions(vault.tokenId());
//     assertGt(position.declaredValue, depositAmount, "Declared value not increased");
// }

// function test_OnERC721Received_DeclaredValueBelowRequired() public {
//     // Create a staking position for user1 with declared value at 110%
//     uint256 depositAmount = 50 ether;
//     uint256 declaredValue = depositAmount * 110 / 100; // 110% of deposit amount
//     vm.startPrank(owner);
//     app.mint(user1, depositAmount);
//     vm.stopPrank();

//     vm.startPrank(user1);
//     app.approve(address(staking), depositAmount);
//     (uint256 tokenId,) = staking.createPosition(user1, depositAmount, declaredValue, 0);

//     // Forward time to ensure position is unlocked
//     vm.warp(block.timestamp + 2 days);

//     // Record vault's position state before transfer
//     IAppStaking.Position memory vaultPositionBefore = staking.positions(vault.tokenId());
//     uint256 vaultAmountBefore = vaultPositionBefore.amount;
//     uint256 vaultDeclaredValueBefore = vaultPositionBefore.declaredValue;
//     uint256 vaultDeclaredValuePercentageBefore = (vaultDeclaredValueBefore * 100) / vaultAmountBefore;

//     // Approve the vault to transfer the NFT
//     staking.approve(address(vault), tokenId);

//     // Transfer the NFT to the vault
//     staking.safeTransferFrom(user1, address(vault), tokenId);
//     vm.stopPrank();

//     // Verify the declared value percentage after merge
//     IAppStaking.Position memory positionAfter = staking.positions(vault.tokenId());
//     uint256 totalAmount = positionAfter.amount;
//     uint256 totalDeclaredValue = positionAfter.declaredValue;
//     uint256 declaredValuePercentage = (totalDeclaredValue * 100) / totalAmount;

//     // Should be at least 130% after merge
//     assertGe(declaredValuePercentage, 130, "Declared value percentage should be at least 130% after merge");
// }

// function test_OnERC721Received_DeclaredValueAboveRequired() public {
//     // Create a staking position for user1 with declared value at 200%
//     uint256 depositAmount = 50 ether;
//     uint256 declaredValue = depositAmount * 200 / 100; // 200% of deposit amount
//     vm.startPrank(owner);
//     app.mint(user1, depositAmount);
//     vm.stopPrank();

//     vm.startPrank(user1);
//     app.approve(address(staking), depositAmount);
//     (uint256 tokenId,) = staking.createPosition(user1, depositAmount, declaredValue, 0);

//     // Forward time to ensure position is unlocked
//     vm.warp(block.timestamp + 2 days);

//     // Record vault's position state before transfer
//     IAppStaking.Position memory vaultPositionBefore = staking.positions(vault.tokenId());
//     uint256 vaultAmountBefore = vaultPositionBefore.amount;
//     uint256 vaultDeclaredValueBefore = vaultPositionBefore.declaredValue;
//     uint256 vaultDeclaredValuePercentageBefore = (vaultDeclaredValueBefore * 100) / vaultAmountBefore;

//     // Approve the vault to transfer the NFT
//     staking.approve(address(vault), tokenId);

//     // Transfer the NFT to the vault
//     staking.safeTransferFrom(user1, address(vault), tokenId);
//     vm.stopPrank();

//     // Verify the declared value percentage after merge
//     IAppStaking.Position memory positionAfter = staking.positions(vault.tokenId());
//     uint256 totalAmount = positionAfter.amount;
//     uint256 totalDeclaredValue = positionAfter.declaredValue;
//     uint256 declaredValuePercentage = (totalDeclaredValue * 100) / totalAmount;

//     // Should maintain at least 130% after merge
//     assertGe(declaredValuePercentage, 130, "Declared value percentage should maintain at least 130% after merge");
// }

// function test_OnERC721Received_DeclaredValueExactRequired() public {
//     // Create a staking position for user1 with declared value at exactly 130%
//     uint256 depositAmount = 50 ether;
//     uint256 declaredValue = depositAmount * 130 / 100; // 130% of deposit amount
//     vm.startPrank(owner);
//     app.mint(user1, depositAmount);
//     vm.stopPrank();

//     vm.startPrank(user1);
//     app.approve(address(staking), depositAmount);
//     (uint256 tokenId,) = staking.createPosition(user1, depositAmount, declaredValue, 0);

//     // Forward time to ensure position is unlocked
//     vm.warp(block.timestamp + 2 days);

//     // Record vault's position state before transfer
//     IAppStaking.Position memory vaultPositionBefore = staking.positions(vault.tokenId());
//     uint256 vaultAmountBefore = vaultPositionBefore.amount;
//     uint256 vaultDeclaredValueBefore = vaultPositionBefore.declaredValue;
//     uint256 vaultDeclaredValuePercentageBefore = (vaultDeclaredValueBefore * 100) / vaultAmountBefore;

//     // Approve the vault to transfer the NFT
//     staking.approve(address(vault), tokenId);

//     // Transfer the NFT to the vault
//     staking.safeTransferFrom(user1, address(vault), tokenId);
//     vm.stopPrank();

//     // Verify the declared value percentage after merge
//     IAppStaking.Position memory positionAfter = staking.positions(vault.tokenId());
//     uint256 totalAmount = positionAfter.amount;
//     uint256 totalDeclaredValue = positionAfter.declaredValue;
//     uint256 declaredValuePercentage = (totalDeclaredValue * 100) / totalAmount;

//     // Should maintain at least 130% after merge
//     assertGe(declaredValuePercentage, 130, "Declared value percentage should maintain at least 130% after merge");
// }

// function test_OnERC721Received_DeclaredValueTaxCalculation() public {
//     // Create a staking position for user1 with declared value at 110%
//     uint256 depositAmount = 50 ether;
//     uint256 declaredValue = depositAmount * 110 / 100; // 110% of deposit amount
//     vm.startPrank(owner);
//     app.mint(user1, depositAmount);
//     vm.stopPrank();

//     vm.startPrank(user1);
//     app.approve(address(staking), depositAmount);
//     (uint256 tokenId,) = staking.createPosition(user1, depositAmount, declaredValue, 0);

//     // Forward time to ensure position is unlocked
//     vm.warp(block.timestamp + 2 days);

//     // Record vault's position state before transfer
//     IAppStaking.Position memory vaultPositionBefore = staking.positions(vault.tokenId());
//     uint256 vaultAmountBefore = vaultPositionBefore.amount;
//     uint256 vaultDeclaredValueBefore = vaultPositionBefore.declaredValue;
//     uint256 vaultDeclaredValuePercentageBefore = (vaultDeclaredValueBefore * 100) / vaultAmountBefore;

//     // Approve the vault to transfer the NFT
//     staking.approve(address(vault), tokenId);

//     // Record balances before transfer
//     uint256 userBalanceBefore = app.balanceOf(user1);

//     // Transfer the NFT to the vault
//     staking.safeTransferFrom(user1, address(vault), tokenId);
//     vm.stopPrank();

//     // Verify the declared value percentage after merge
//     IAppStaking.Position memory positionAfter = staking.positions(vault.tokenId());
//     uint256 totalAmount = positionAfter.amount;
//     uint256 totalDeclaredValue = positionAfter.declaredValue;
//     uint256 declaredValuePercentage = (totalDeclaredValue * 100) / totalAmount;

//     // Should be at least 130% after merge
//     assertGe(declaredValuePercentage, 130, "Declared value percentage should be at least 130% after merge");

//     // Verify tax was paid
//     uint256 userBalanceAfter = app.balanceOf(user1);
//     assertEq(userBalanceAfter, userBalanceBefore, "User should have not paid tax");
// }

// function test_OnERC721Received_ShareMintingCalculation() public {
//     // Create a new staking position for user1 with 50 RZR
//     uint256 userDeposit = 50 ether;
//     uint256 declaredValue = userDeposit * 130 / 100; // 130% of deposit amount
//     vm.startPrank(owner);
//     app.mint(user1, userDeposit);
//     vm.stopPrank();

//     vm.startPrank(user1);
//     app.approve(address(staking), userDeposit);
//     (uint256 tokenId,) = staking.createPosition(user1, userDeposit, declaredValue, 0);

//     // Forward time to ensure position is unlocked
//     vm.warp(block.timestamp + 2 days);

//     // Record vault state before transfer
//     uint256 vaultSharesBefore = vault.totalSupply();
//     uint256 vaultAssetsBefore = staking.positions(vault.tokenId()).amount;

//     // Approve and transfer NFT to vault
//     staking.approve(address(vault), tokenId);
//     staking.safeTransferFrom(user1, address(vault), tokenId);
//     vm.stopPrank();

//     // Verify the NFT was merged and burnt
//     vm.expectRevert();
//     staking.ownerOf(tokenId);

//     assertEq(vault.balanceOf(user1), 46.75 ether, "User should have right shares");

//     // Calculate expected shares
//     // Shares should be proportional to the added assets relative to total assets
//     uint256 vaultAssetsAfter = staking.positions(vault.tokenId()).amount;
//     uint256 addedAssets = vaultAssetsAfter - vaultAssetsBefore;
//     uint256 expectedShares = (addedAssets * vaultSharesBefore) / vaultAssetsBefore;

//     // Verify shares were minted correctly
//     uint256 userShares = vault.balanceOf(user1);
//     assertEq(userShares, expectedShares, "Incorrect number of shares minted");

//     // Verify total supply increased by the correct amount
//     uint256 vaultSharesAfter = vault.totalSupply();
//     assertEq(vaultSharesAfter - vaultSharesBefore, expectedShares, "Total supply not increased correctly");
// }

// function test_OnERC721Received_ShareMintingWithRewards() public {
//     // Add some rewards to the vault's position
//     uint256 rewardAmount = 20 ether;
//     vm.startPrank(owner);
//     app.mint(owner, rewardAmount);
//     app.approve(address(staking), rewardAmount);
//     staking.notifyRewardAmount(rewardAmount);
//     vm.stopPrank();

//     // Wait for rewards to accrue
//     vm.warp(block.timestamp + 1 days);

//     // Harvest rewards to compound them
//     vm.prank(owner);
//     vault.harvest();

//     // Create a new staking position for user1 with 50 RZR
//     uint256 userDeposit = 50 ether;
//     uint256 declaredValue = userDeposit * 130 / 100; // 130% of deposit amount
//     vm.startPrank(owner);
//     app.mint(user1, userDeposit);
//     vm.stopPrank();

//     vm.startPrank(user1);
//     app.approve(address(staking), userDeposit);
//     (uint256 tokenId,) = staking.createPosition(user1, userDeposit, declaredValue, 0);

//     // Forward time to ensure position is unlocked
//     vm.warp(block.timestamp + 2 days);

//     // Record vault state before transfer
//     uint256 vaultSharesBefore = vault.totalSupply();
//     uint256 vaultAssetsBefore = staking.positions(vault.tokenId()).amount;

//     // Approve and transfer NFT to vault
//     staking.approve(address(vault), tokenId);
//     staking.safeTransferFrom(user1, address(vault), tokenId);
//     vm.stopPrank();

//     // Calculate expected shares
//     uint256 vaultAssetsAfter = staking.positions(vault.tokenId()).amount;
//     uint256 addedAssets = vaultAssetsAfter - vaultAssetsBefore;
//     uint256 expectedShares = (addedAssets * vaultSharesBefore) / vaultAssetsBefore;

//     // Verify shares were minted correctly
//     uint256 userShares = vault.balanceOf(user1);
//     assertEq(userShares, expectedShares, "Incorrect number of shares minted with rewards");

//     // Verify total supply increased by the correct amount
//     uint256 vaultSharesAfter = vault.totalSupply();
//     assertEq(
//         vaultSharesAfter - vaultSharesBefore, expectedShares, "Total supply not increased correctly with rewards"
//     );
// }

// function test_fork_4626_staking_1() public {
//     uint256 mainnetFork = vm.createFork("https://rpc.soniclabs.com");
//     vm.selectFork(mainnetFork);
//     vm.roll(34191641);

//     AppStaking stakingFork = AppStaking(0xd060499DDC9cb7deB07f080BAeB1aDD36AA2C650);
//     RZR appFork = RZR(0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5);
//     address whaleFork = 0x0d04b2f9E8f769f29FFB35d48333867Bb0207868;
//     address deployerFork = 0x0b414acAEb4Ad3d60B7daE6E14D2b9168DA5Ce76;
//     uint256 tokenId = 4;

//     uint256 stakingBalance = stakingFork.positions(tokenId).amount;

//     vault = new Staking4626();
//     authority = new AppAuthority();
//     vault.initialize("RZR Vault", "vRZR", address(stakingFork), address(authority));

//     vm.startPrank(deployerFork);
//     appFork.approve(address(vault), 1e18);
//     vault.initializePosition(1e18);
//     vm.stopPrank();

//     uint256 vaultTokenId = vault.tokenId();

//     vm.startPrank(whaleFork);
//     stakingFork.safeTransferFrom(whaleFork, address(vault), tokenId);
//     vm.stopPrank();

//     uint256 vaultBalance = vault.balanceOf(whaleFork);
//     uint256 vaultTotalSupply = vault.totalSupply();

//     assertApproxEqAbs(vaultBalance, 26716e18, 1e18, "Vault balance for whale should be correct");
// }

// function test_fork_4626_staking_2() public {
//     uint256 mainnetFork = vm.createFork("https://rpc.soniclabs.com");
//     vm.selectFork(mainnetFork);
//     vm.roll(34191641);

//     AppStaking stakingFork = AppStaking(0xd060499DDC9cb7deB07f080BAeB1aDD36AA2C650);
//     RZR appFork = RZR(0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5);
//     Staking4626 vaultFork = Staking4626(0x67A298e5B65dB2b4616E05C3b455E017275f53cB);
//     address whaleFork = 0x0d04b2f9E8f769f29FFB35d48333867Bb0207868;
//     address deployerFork = 0x0b414acAEb4Ad3d60B7daE6E14D2b9168DA5Ce76;
//     uint256 tokenId = 4;

//     uint256 stakingBalance = stakingFork.positions(tokenId).amount;

//     uint256 vaultTokenId = vaultFork.tokenId();

//     vm.startPrank(whaleFork);
//     stakingFork.safeTransferFrom(whaleFork, address(vaultFork), tokenId);
//     vm.stopPrank();

//     uint256 vaultBalance = vaultFork.balanceOf(whaleFork);
//     uint256 vaultTotalSupply = vaultFork.totalSupply();

//     assertApproxEqAbs(vaultBalance, 26716e18, 1e18, "Vault balance for whale should be correct");
// }
}

// Mock NFT contract for testing invalid sender
contract MockNFT {
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
    }
}
