// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../BaseTest.sol";

/// @title RebaseInvariant
/// @notice Invariant tests ensuring rebase operations keep the treasury fully backed and appropriately sized.
contract RebaseInvariant is BaseTest {
    // Cached metrics from the previous invariant iteration.
    uint256 private lastBackingRatioE18;
    uint256 private lastSupply;
    uint256 private lastReserves;

    function setUp() public {
        setUpBaseTest();

        // Seed credit reserves so that treasury has excess and we can mint.
        vm.startPrank(owner);
        authority.addPolicy(owner);
        treasury.setCreditReserves(1_000_000e18);

        // Ensure some initial supply so the BR denominator is never zero.
        treasury.mint(owner, 1e18);
        vm.stopPrank();

        // Initialise trackers.
        _snapshotState();

        // Allow the fuzzer to call our helper functions plus the burner & controller directly.
        targetContract(address(this));
        targetContract(address(rebaseController));
        targetContract(address(burner));

        // Use `owner` as the msg.sender for calls that require privileged access.
        targetSender(owner);
    }

    /*//////////////////////////////////////////////////////////////////////////
                              Helpers callable by fuzzer
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Advance time by one epoch (plus some buffer) and attempt to execute a rebase.
    function advanceAndRebase() external {
        uint256 next = block.timestamp + rebaseController.EPOCH() + 1;
        vm.warp(next);

        // Execute epoch as the privileged executor.
        vm.prank(owner);
        try rebaseController.executeEpoch() {}
        catch {
            // Ignored – could revert if insufficient reserves.
        }
    }

    /// @notice Trigger a burn via the burner contract if it holds any RZR.
    function triggerBurn() external {
        uint256 bal = app.balanceOf(address(burner));
        if (bal > 0) {
            vm.prank(owner);
            try burner.burn() {}
            catch {
                // ignore errors (e.g., constraints not met).
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Invariants
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev The treasury backing ratio must never fall below 1 (100%).
    function invariant_BackingRatioGTEOne() external view {
        assertGe(treasury.backingRatioE18(), 1e18);
    }

    /// @dev Tokens minted or burned during a supply change must respect excess reserves logic and affect BR proportionally.
    function invariant_SupplyChangesRespectBacking() external {
        uint256 currentSupply = treasury.totalSupply();
        uint256 currentReserves = treasury.totalReserves();
        uint256 currentBR = treasury.backingRatioE18();

        if (currentSupply != lastSupply) {
            if (currentSupply > lastSupply) {
                // Mint scenario
                uint256 minted = currentSupply - lastSupply;
                uint256 prevExcess = lastReserves > lastSupply ? lastReserves - lastSupply : 0;
                // Minted tokens must come out of excess reserves (enforced in controller)
                assertLe(minted, prevExcess);
                // Backing ratio should decrease (or remain) but remain >=1.
                assertLe(currentBR, lastBackingRatioE18);
            } else {
                // Burn scenario
                uint256 burned = lastSupply - currentSupply;
                // Burning should increase backing ratio.
                assertGe(currentBR, lastBackingRatioE18);
                // Burned amount should not exceed previous supply.
                assertLe(burned, lastSupply);
            }
        }

        // Update snapshots for next run.
        lastSupply = currentSupply;
        lastReserves = currentReserves;
        lastBackingRatioE18 = currentBR;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      Internal
    //////////////////////////////////////////////////////////////////////////*/
    function _snapshotState() internal {
        lastReserves = treasury.totalReserves();
        lastSupply = treasury.totalSupply();
        lastBackingRatioE18 = treasury.backingRatioE18();
    }
}
