// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

/**
 * @notice Library‐style contract that, given one epoch's inputs, returns:
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
    // --- Constants -----------------------------------------------------------
    uint256 public constant FLOOR_RATIO_MIN = 15; // 15% to floor at 0% staking
    uint256 public constant FLOOR_RATIO_MAX = 50; // 50% to floor at 100% staking
    uint256 public constant OPS_RATIO = 10; // 10% to operations
    uint256 public constant FLOOR_PRICE_INCREASE = 1; // 1% increase per epoch

    function allocate(uint256 yield, uint256 totalSupply, uint256 stakedSupply, uint256 floorPrice)
        public
        pure
        returns (uint256 toStakers, uint256 toOps, uint256 newFloorPrice)
    {
        if (yield == 0) return (0, 0, floorPrice);

        // Calculate staking ratio (0-100%)
        uint256 stakingRatio = (stakedSupply * 100) / totalSupply;

        // Calculate floor ratio based on staking ratio
        // Linear interpolation between FLOOR_RATIO_MIN and FLOOR_RATIO_MAX
        uint256 floorRatio = FLOOR_RATIO_MIN + ((FLOOR_RATIO_MAX - FLOOR_RATIO_MIN) * stakingRatio) / 100;

        // Calculate allocations
        uint256 toFloor = (yield * floorRatio) / 100;
        toOps = (yield * OPS_RATIO) / 100;
        toStakers = yield - toFloor - toOps;

        // Calculate new floor price
        newFloorPrice = floorPrice + (floorPrice * FLOOR_PRICE_INCREASE) / 100;
    }
}
