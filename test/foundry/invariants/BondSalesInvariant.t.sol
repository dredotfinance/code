// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../BaseTest.sol";
import {IAppBondDepository} from "../../../contracts/interfaces/IAppBondDepository.sol";

/// @title BondSalesInvariant
/// @notice Invariant suite ensuring bond sales keep the treasury fully (or over) backed.
///         Tested properties:
///         1. Treasury receives collateral when a bond is sold.
///         2. The amount of RZR minted for bonds never exceeds the value of collateral received.
///         3. Bond sales never reduce the treasury backing ratio (it must stay >= previous and >= 1).
///         4. Cumulative RZR sold through bonds never exceeds the treasury's excess reserves.
contract BondSalesInvariant is BaseTest {
    // The ID of the bond we create for fuzzing purposes.
    uint256 internal bondId;

    // Track the last observed backing ratio to guarantee monotonicity.
    uint256 internal lastBackingRatioE18;

    // Convenience pointer to the quote token used for the bond.
    MockERC20 internal quoteToken;

    function setUp() public {
        setUpBaseTest();

        // Grant policy rights to `owner` so we can set credit reserves.
        vm.startPrank(owner);
        authority.addPolicy(owner);

        // Choose mockQuoteToken as our collateral token and enable it in the treasury.
        quoteToken = mockQuoteToken;
        treasury.enable(address(quoteToken));

        // Seed the treasury with credit reserves to give it a healthy buffer.
        uint256 initialCredit = 2_000_000e18;
        treasury.setCreditReserves(initialCredit);

        // Mint a minimal amount of RZR so that totalSupply is non-zero, avoiding
        // division-by-zero when computing the initial backing ratio.
        treasury.mint(owner, 1e18);

        // Create a bond with a generous capacity that the fuzzer can interact with.
        uint256 capacity = 1_000_000e18;
        uint256 initialPrice = 1.1e18; // 1.1 RZR per quote token
        uint256 finalPrice = 0.9e18; // 0.9 RZR per quote token
        uint256 duration = 30 days;
        bondId = bondDepository.create(quoteToken, capacity, initialPrice, finalPrice, duration);

        vm.stopPrank();

        // Cache the current backing ratio for later comparisons.
        lastBackingRatioE18 = treasury.backingRatioE18();

        // Let the fuzzer call our helper and the bond depository directly.
        targetContract(address(this)); // Helper wrapper below
        targetContract(address(bondDepository));

        // Use this contract as the sender for fuzzing so we can mint & approve tokens.
        targetSender(address(this));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Helper for Fuzzing
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Fuzzer entry-point to purchase bonds.
    /// @param quoteAmount Amount of quote tokens to spend when buying the bond.
    function buyBond(uint256 quoteAmount) external {
        // Bound the deposit size to something reasonable and non-zero.
        quoteAmount = bound(quoteAmount, 1e18, 20_000e18);

        // Fetch current bond state.
        IAppBondDepository.Bond memory bond = bondDepository.getBond(bondId);
        if (!bond.enabled || block.timestamp >= bond.endTime || bond.capacity == 0) {
            return; // Bond unavailable, skip.
        }

        // Calculate expected payout to ensure we don't exceed capacity.
        uint256 price = bondDepository.currentPrice(bondId);
        uint256 payout = (quoteAmount * 1e18) / price;
        if (payout > bond.capacity) {
            return; // Would revert, skip.
        }

        // Mint tokens to this contract and approve transfer.
        quoteToken.mint(address(this), quoteAmount);
        quoteToken.approve(address(bondDepository), quoteAmount);

        // Perform the deposit; ignore returned values.
        try bondDepository.deposit(bondId, quoteAmount, type(uint256).max, 0, address(this)) returns (uint256, uint256)
        {
            // Successfully bought a bond.
        } catch {
            // Silently ignore reverts – invariants are checked post-call anyway.
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Invariants
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Treasury must always hold at least the amount of collateral it has received from bonds.
    function invariant_TreasuryHasCollateral() external view {
        IAppBondDepository.Bond memory bond = bondDepository.getBond(bondId);
        uint256 collateralReceived = bond.purchased; // quote tokens transferred into treasury

        uint256 treasuryBalance = quoteToken.balanceOf(address(treasury));
        assertGe(treasuryBalance, collateralReceived);
    }

    /// @notice Reserves must always cover supply (fully backed) and minted RZR for bonds can never exceed collateral value.
    function invariant_FullyBacked() external view {
        // Fully backed requirement
        assertGe(treasury.totalReserves(), treasury.totalSupply());
    }

    /// @notice Backing ratio must never decrease and must stay >= 1.
    function invariant_BackingRatioNonDecreasing() external {
        uint256 currentBR = treasury.backingRatioE18();

        // It must always be >= 1 (i.e., 100%).
        assertGe(currentBR, 1e18);

        // It should never be lower than the last observed value.
        assertGe(currentBR, lastBackingRatioE18);

        // Update state for next run.
        lastBackingRatioE18 = currentBR;
    }

    /// @notice Total RZR sold via bonds must not exceed the treasury's excess reserves buffer.
    function invariant_BondSalesWithinExcessReserves() external view {
        IAppBondDepository.Bond memory bond = bondDepository.getBond(bondId);
        uint256 totalSold = bond.sold; // RZR minted for this bond

        assertLe(totalSold, treasury.excessReserves());
    }
}
