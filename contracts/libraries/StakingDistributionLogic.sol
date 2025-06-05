// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

/**
 * @notice Library‐style contract that, given one epoch’s inputs, returns:
 *         - how many DRE tokens to mint to stakers
 *         - how much of the inflow (in USD-units) goes to the oracle floor
 *         - how much goes to the ops wallet
 *         - the bumped floor price (if the 5 % surplus rule is met)
 *
 * @dev All dollar values use 18-decimals fixed-point (1e18 == 1 USD).
 *      The caller must pass in `supply` (current circulating DRE) so the
 *      function can test whether the floor should ratchet.
 */
library StakingDistributionLogic {
    uint256 private constant ONE = 1e18; // 100 %
    uint256 private constant TEN_PCT = 0.1e18; // 10 %
    uint256 private constant FIFTEEN_PCT = 0.15e18;
    uint256 private constant FIFTY_PCT = 0.5e18;

    struct Result {
        uint256 toStakers;
        uint256 toOps;
        uint256 newFloorPrice;
    }

    function allocate(
        uint256 yieldTokens, // 18-dec
        uint256 totalSupply, // 18-dec
        uint256 stakedSupply, // 18-dec
        uint256 floorPrice // 18-dec USD
    ) internal pure returns (Result memory out) {
        out.newFloorPrice = floorPrice;
        if (totalSupply == 0) return out;
        if (floorPrice == 0) return out;

        //--------------------------------------------------------------
        // 1. derive staking ratio ρ  =  staked / total
        //--------------------------------------------------------------
        uint256 rho = (totalSupply == 0) ? 0 : (stakedSupply * ONE) / totalSupply;

        //--------------------------------------------------------------
        // 2. decide split percentages
        //    floorPct = min(15 % + 50 %·ρ , 50 %)
        //--------------------------------------------------------------
        uint256 floorPct = FIFTEEN_PCT + (rho * FIFTY_PCT) / ONE; // 15 % + 50 %·ρ
        if (floorPct > FIFTY_PCT) floorPct = FIFTY_PCT;

        uint256 opsPct = TEN_PCT;
        uint256 stakePct = ONE - floorPct - opsPct; // rest to stakers

        //--------------------------------------------------------------
        // 3. token distribution
        //--------------------------------------------------------------
        out.toOps = yieldTokens * opsPct / ONE;
        out.toStakers = yieldTokens * stakePct / ONE;

        //--------------------------------------------------------------
        // 4. raise the oracle floor by the share routed to floorPct
        //    ΔFloor = floor × floorPct × yield / total
        //--------------------------------------------------------------
        uint256 deltaFloor = floorPrice * floorPct / ONE * yieldTokens / totalSupply;

        out.newFloorPrice = floorPrice + deltaFloor;
    }
}
