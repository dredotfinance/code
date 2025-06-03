// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "./BaseTest.sol";
import "../contracts/RebaseController.sol";
import "../contracts/Dre.sol";
import "../contracts/sDRE.sol";
import "../contracts/DreTreasury.sol";
import "../contracts/DreStaking.sol";
import "../contracts/mocks/MockERC20.sol";
import "../contracts/mocks/MockAggregatorV3.sol";

contract RebaseControllerTest is BaseTest {
    event Rebased(uint256 backingRatio, uint256 epochRate, uint256 tokensMinted);

    function setUp() public {
        setUpBaseTest();

        vm.startPrank(owner);
        dreAuthority.addPolicy(owner);

        // Mint some quote tokens to treasury to simulate PCV
        mockQuoteToken.mint(address(treasury), 1_000_000e18);
        treasury.syncReserves();
    }

    function test_Initialization() public view {
        assertEq(address(rebaseController.dre()), address(dre));
        assertEq(address(rebaseController.treasury()), address(treasury));
        assertEq(address(rebaseController.staking()), address(staking));
        assertEq(rebaseController.lastEpochTime(), block.timestamp);
    }

    function test_BackingRatioZeroSupply() public view {
        assertEq(rebaseController.currentBackingRatio(), 0);
    }

    function test_BackingRatioWithSupply() public {
        // Mint some DRE tokens to simulate supply
        dre.mint(owner, 1_000_000e18);

        // Treasury has 1M quote tokens (1:1 price)
        uint256 backingRatio = rebaseController.currentBackingRatio();
        assertEq(backingRatio, 1e18); // 1:1 backing
    }

    function test_ProjectedEpochRateZeroSupply() public view {
        (uint256 apr, uint256 epochRate, uint256 backingRatio) = rebaseController.projectedEpochRate();
        assertEq(apr, 0);
        assertEq(epochRate, 0);
        assertEq(backingRatio, 0);
    }

    function test_ProjectedEpochRateWithBacking() public {
        // Mint DRE tokens to create supply
        dre.mint(owner, 1_000_000e18);

        // Test with 1:1 backing (100%)
        (uint256 apr, uint256 epochRate, uint256 backingRatio) = rebaseController.projectedEpochRate();
        assertEq(backingRatio, 1e18);
        assertEq(apr, 0); // Below 100% backing

        // Add more PCV to treasury to increase backing ratio
        mockQuoteToken.mint(address(treasury), 500_000e18);
        treasury.syncReserves();

        // Test with 1.5:1 backing (150%)
        (apr, epochRate, backingRatio) = rebaseController.projectedEpochRate();
        assertEq(backingRatio, 1.5e18);
        assertEq(apr, 1000); // Should have positive APR
    }

    function test_ExecuteEpochBeforeReady() public {
        vm.expectRevert("epoch not ready");
        rebaseController.executeEpoch();
    }

    function test_ExecuteEpochSuccess() public {
        // Mint DRE tokens to create supply
        dre.mint(owner, 1_000_000e18);
        dre.mint(user1, 1_000e18);

        // Add PCV to treasury to ensure positive rebase
        mockQuoteToken.mint(address(treasury), 2_000_000e18);
        treasury.syncReserves();

        // stake some tokens so that rewards can accumulate
        dre.approve(address(staking), 100e18);
        staking.createPosition(user1, 100e18, 100e18, 0);

        // Fast forward to next epoch
        uint256 epochLength = rebaseController.EPOCH();
        vm.warp(block.timestamp + epochLength);

        // Execute epoch
        (, uint256 epochRate, uint256 backingRatio) = rebaseController.projectedEpochRate();
        uint256 tokensMinted = (dre.totalSupply() * epochRate) / 1e18;

        vm.expectEmit(true, true, true, true);
        emit Rebased(backingRatio, epochRate, tokensMinted);

        rebaseController.executeEpoch();

        // Verify rewards were minted and sent to staking
        uint256 stakingBalance = dre.balanceOf(address(staking));
        assertGt(stakingBalance, 0);
    }

    function test_ExecuteEpochInsufficientReserves() public {
        // Mint DRE tokens to create supply
        dre.mint(owner, 1_000_000e18);

        // Don't add any PCV to treasury

        // Fast forward to next epoch
        uint256 epochLength = rebaseController.EPOCH();
        vm.warp(block.timestamp + epochLength);

        // Execute epoch should succeed but not mint rewards
        vm.expectEmit(true, true, true, true);
        emit Rebased(1e18, 0, 0);

        rebaseController.executeEpoch();

        // Verify no rewards were minted
        uint256 stakingBalance = dre.balanceOf(address(staking));
        assertEq(stakingBalance, 0);
    }

    function test_ProjectedEpochRateRaw() public view {
        // Test with zero supply
        (uint256 apr, uint256 epochRate, uint256 backingRatio) = rebaseController.projectedEpochRateRaw(1e18, 0);
        assertEq(apr, 0);
        assertEq(epochRate, 0);
        assertEq(backingRatio, 0);

        // Test with 1:1 backing
        (apr, epochRate, backingRatio) = rebaseController.projectedEpochRateRaw(1e18, 1e18);
        assertEq(backingRatio, 1e18);
        assertEq(apr, 0); // Below 100% backing

        // Test with 1.5:1 backing
        (apr, epochRate, backingRatio) = rebaseController.projectedEpochRateRaw(3e18, 2e18);
        assertEq(backingRatio, 1.5e18);
        assertEq(apr, 500); // Should have positive APR

        // Test with 2:1 backing
        (apr, epochRate, backingRatio) = rebaseController.projectedEpochRateRaw(3e18, 1.5e18);
        assertEq(backingRatio, 2e18);
        assertEq(apr, 1000); // Should have positive APR

        // Test with 2.5:1 backing
        (apr, epochRate, backingRatio) = rebaseController.projectedEpochRateRaw(2.5e18, 1e18);
        assertEq(backingRatio, 2.5e18);
        assertEq(apr, 2000); // Should be at CEIL_APR
    }
}
