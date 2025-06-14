// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/periphery/security/UnbackedFreeze.sol";

contract UnbackedFreezeTest is BaseTest {
    UnbackedFreeze public freeze;

    function setUp() public {
        // Deploy foundational protocol stack
        setUpBaseTest();

        vm.startPrank(owner);

        // Deploy the UnbackedFreeze contract
        freeze = new UnbackedFreeze(address(treasury), address(staking), address(bondDepository), address(authority));

        // Give the contract guardian rights so that it can successfully pause
        authority.addGuardian(address(freeze));

        // Ensure the caller (owner) has executor rights (already granted in BaseTest but re-assert for clarity)
        authority.addExecutor(owner);

        vm.stopPrank();
    }

    function test_Evaluate_NoPause_WhenHealthy() public {
        // Pre-condition: protocol healthy (no bad debt)
        assertEq(freeze.currentBadDebt(), 0);
        assertFalse(treasury.paused(), "Treasury should start unpaused");

        // Call evaluateAndAct as executor
        vm.prank(owner);
        freeze.evaluateAndAct();

        // Post-condition: still unpaused
        assertFalse(treasury.paused(), "Treasury should remain unpaused when invariant passes");
    }

    function test_Evaluate_Pauses_WhenBadDebt() public {
        // Introduce bad debt: mint >10k RZR without backing
        uint256 mintAmount = 11_000 * 1e18;

        vm.startPrank(owner);
        app.mint(owner, mintAmount);

        // Sanity: bad debt should now exceed threshold
        uint256 expectedBadDebt = mintAmount; // reserves are zero
        assertEq(freeze.currentBadDebt(), expectedBadDebt);
        assertGt(expectedBadDebt, freeze.BAD_DEBT_THRESHOLD());

        // Execute evaluator (as executor)
        freeze.evaluateAndAct();

        // Treasury should now be paused since the call originates from a guardian-authorised contract
        assertTrue(treasury.paused(), "Treasury should be paused when bad debt exceeds threshold");

        vm.stopPrank();
    }
}
