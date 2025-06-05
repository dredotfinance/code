// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

/**
 * @title YieldLogic
 * @notice Pure‐math helper for DRE's "capped-inflation" policy.
 *
 *  • Calculates the current APR band from collateral backing.
 *  • Converts the APR into the exact number of tokens to mint
 *    for a single epoch (defaults to 8-hour epochs → 1 095/yr).
 *
 *  INPUTS
 *  ──────────────────────────────────────────────────────────────
 *    pcv   – USD-value (18-dec) of risk-free assets in PCV
 *    totalSupply        – Circulating DRE before this epoch (18-dec)
 *    floorPrice         – Oracle floor price (USD, 18-dec) *not* needed
 *                         for APR, but kept here in case callers want
 *                         to price stake-mint from inflow in one call.
 *
 *  APR Curve
 *  ──────────────────────────────────────────────────────────────
 *    β < 1.0                        → 0     %
 *    1.0 ≤ β < 1.5                 → 0 → 500  %  (linear)
 *    1.5 ≤ β < 2.0                 → 500     %
 *    2.0 ≤ β < 2.5                 → 500 → 2 000 % (linear)
 *    β ≥ 2.5                       → 2 000 %
 */
library YieldLogic {
    // --- Constants -----------------------------------------------------------
    uint16 public constant FLOOR_APR = 500; // 500% APR
    uint16 public constant CEIL_APR = 2000; // 2000% APR
    uint16 public constant K1 = 10; // rises 0->500% over β 1-1.5
    uint16 public constant K2 = 1500; // rises 500->2000% over β 1.5-2.5

    function calcEpoch(uint256 pcvUsd, uint256 supply, uint256 epochsPerYear)
        public
        pure
        returns (uint256 apr, uint256 epochMint)
    {
        if (supply == 0) return (0, 0);

        uint256 backingRatio = (pcvUsd * 1e18) / supply;
        uint256 beta1e2 = backingRatio / 1e16;

        if (beta1e2 < 100) {
            apr = 0;
        } else if (beta1e2 < 150) {
            apr = (beta1e2 - 100) * K1;
        } else if (beta1e2 < 250) {
            apr = FLOOR_APR + ((beta1e2 - 150) * K2) / 100;
        } else {
            apr = CEIL_APR;
        }

        if (apr > CEIL_APR) apr = CEIL_APR;

        epochMint = (supply * apr) / (100 * epochsPerYear);
    }
}
