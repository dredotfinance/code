// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import "../foundry/BaseTest.sol";

/// @title TreasuryInvariant – Halmos invariant test for collateralization
/// @notice Ensures `totalReserves()` is always ≥ `totalSupply()` (excluding `unbackedSupply`).
///         Assumptions:
///           1. Oracle prices stay constant.
///           2. New RZR tokens can only be minted via `deposit` (treasury) or `executeEpoch` (rebase controller).
contract TreasuryInvariant is BaseTest, SymTest {
    /// @dev Halmos entry point. Symbolically explores the sequence:
    ///      1. A reserve depositor deposits an arbitrary amount of quote token.
    ///      2. Optionally (if possible) a rebase epoch is executed.
    ///      3. Invariant ‑ totalReserves ≥ totalSupply ‑ must hold.
    function check_treasury_overcollateralized() public {
        // ───────────────────────  Setup  ──────────────────────────
        setUpBaseTest();

        // Grant this test contract RESERVE_DEPOSITOR role so it can call `deposit`.
        authority.addReserveDepositor(address(this));

        // ───────────────  Symbolic deposit amount  ───────────────
        uint256 depositAmount = svm.createUint256("depositAmount");
        // Apply practical bounds so Halmos search space is finite & avoids overflow.
        vm.assume(depositAmount > 0 && depositAmount < 1e24);

        // Mint quote tokens and approve Treasury.
        mockQuoteToken.mint(address(this), depositAmount);
        mockQuoteToken.approve(address(treasury), depositAmount);

        // Perform the deposit (profit = 0 for simplicity).
        treasury.deposit(depositAmount, address(mockQuoteToken), 0);

        // ─────────────  Optional symbolic rebase step  ────────────
        // Advance time so an epoch is eligible.
        vm.warp(block.timestamp + 9 hours);
        // Try to execute an epoch; if it reverts due to lack of excess reserves,
        // we simply continue – the invariant is still required to hold.
        try RebaseController(address(rebaseController)).executeEpoch() {
            // execution succeeded – nothing else to do.
        } catch {
            // ignore reverts; assumption permits epochs only when executable.
        }

        // ─────────────────  Invariant assertion  ──────────────────
        uint256 reserves = treasury.totalReserves();
        uint256 supply = treasury.totalSupply(); // already excludes unbackedSupply
        assertGe(reserves, supply);
    }
}
