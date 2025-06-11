// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

/**
 * @notice Library‐style contract that, given one epoch's inputs, returns:
 *         - how many RZR tokens to mint to stakers
 *         - how much of the inflow (in USD-units) goes to the oracle floor
 *         - how much goes to the ops wallet
 *         - the bumped floor price (if the 5 % surplus rule is met)
 *
 * @dev All dollar values use 18-decimals fixed-point (1e18 == 1 USD).
 *      The caller must pass in `supply` (current circulating RZR) so the
 *      function can test whether the floor should ratchet.
 *
 *  Inputs
 *  ──────
 *  • yieldTokens   – fresh tokens created by the rebase engine this epoch
 *  • totalSupply   – circulating supply *before* mint
 *  • stakedSupply  – amount of RZR already locked in the staking vault
 *
 *  Outputs
 *  ───────
 *  • toStakers     – tokens that go to the staking contract
 *  • toOps         – tokens that go to the DAO operations wallet (10 %)
 *  • toBurner      – tokens that go to the burner contract
 */
library StakingDistributionLogic {
    uint256 private constant ONE = 1e18; // 100 %

    function allocate(
        uint256 yield,
        uint256 totalSupply,
        uint256 stakedSupply,
        uint256 targetOpsPct, // ideally 10%
        uint256 minFloorPct, // minimum to the floor price ideally 15%
        uint256 maxFloorPct, // maximum to the floor price ideally 50%
        uint256 floorSlope // ideally 50%
    ) public pure returns (uint256 toStakers, uint256 toOps, uint256 toBurner) {
        if (yield == 0 || totalSupply == 0) return (0, 0, 0);

        uint256 floorPct;
        {
            // 1. derive staking ratio ρ  =  staked / total
            //--------------------------------------------------------------

            // See the graph below for the relationship between the staking ratio and the floor price.
            // https://www.desmos.com/calculator/lqby6vttdy

            uint256 rho = (totalSupply == 0) ? 0 : (stakedSupply * ONE) / totalSupply;

            //--------------------------------------------------------------
            // 2. decide split percentages
            //    floorPct = min(15 % + 45 %·ρ , 50 %)
            //--------------------------------------------------------------

            floorPct = minFloorPct + (rho * floorSlope) / ONE; // 15 % + 50 %·ρ
            if (floorPct > maxFloorPct) floorPct = maxFloorPct;

            uint256 opsPct = targetOpsPct;
            uint256 stakePct = ONE - floorPct - opsPct; // rest to stakers

            //--------------------------------------------------------------
            // 3. token distribution
            //--------------------------------------------------------------
            toOps = yield * opsPct / ONE;
            toStakers = yield * stakePct / ONE;
            toBurner = yield * floorPct / ONE;
        }
    }
}
