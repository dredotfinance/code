// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IDRE.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IDreStaking.sol";
import "./interfaces/IRebaseController.sol";
import "./DreAccessControlled.sol";

/**
 * @title BondController
 * @dev Minimal reference implementation of DRE's bonding-curve logic.
 *      ─ Calculates backing ratio β = PCV / supply
 *      ─ Determines epochic rebase rate r_t using piece-wise curve
 *      ─ Mints DRE supply for stakers each epoch once called by a keeper
 *      ─ Exposes view helpers for front-end gauges
 *
 *  NOTE:  This is a skeleton for demonstration. Production code must integrate:
 *          ▸ PCV accounting across multiple assets via an oracle aggregator
 *          ▸ access-control (onlyPolicy) on state-changing functions
 *          ▸ event emission for transparency & off-chain indexers
 *          ▸ per-asset risk-weighting, circuit-breakers, and RBS / inverse-bond hooks
 */
contract RebaseController is DreAccessControlled, IRebaseController {
    IDRE public dre; // DRE token (decimals = 18)
    ITreasury public treasury;
    IDreStaking public staking; // staking contract or escrow

    // --- Epoch params --------------------------------------------------------
    uint256 public immutable EPOCH = 8 hours;
    uint256 public lastEpochTime;

    // piece-wise k slopes (all in APR %, 2 decimals eg 5000 = 5000%)
    uint16 public immutable K1 = 500; // rises 0->500 % over β 1-1.5
    uint16 public immutable K2 = 4000; // rises 1000->5000 % over β 1.5-2.5 (slope 2k% per 0.5)

    uint16 public immutable FLOOR_APR = 1000; // 1000 % APR (≈0.092% per 8h)
    uint16 public immutable CEIL_APR = 5000; // 5000 % APR (≈0.46% per 8h)

    function initialize(address _dre, address _treasury, address _staking, address _authority) public initializer {
        dre = IDRE(_dre);
        treasury = ITreasury(_treasury);
        staking = IDreStaking(_staking);
        lastEpochTime = block.timestamp;
        __DreAccessControlled_init(_authority);

        dre.approve(address(staking), type(uint256).max);
    }

    // --- Public keeper call --------------------------------------------------
    function executeEpoch() external {
        require(block.timestamp >= lastEpochTime + EPOCH, "epoch not ready");

        (uint256 apr, uint256 epochRate, uint256 backingRatio) = projectedEpochRate();

        uint256 mintAmount = (dre.totalSupply() * epochRate) / 1e18;
        require(mintAmount <= treasury.excessReserves(), "Insufficient reserves");
        if (mintAmount > 0 && apr > 0) {
            // mintAmount is the amount of DRE to mint
            dre.mint(address(this), mintAmount);

            // send 95% to staking
            staking.notifyRewardAmount(mintAmount * 95 / 100);

            // send 5% to treasury to cover bribes and rewards
            dre.transfer(address(authority.operationsTreasury()), mintAmount * 5 / 100);
        }

        lastEpochTime = block.timestamp;
        emit Rebased(backingRatio, epochRate, mintAmount);
    }

    // --- View helpers --------------------------------------------------------
    function currentBackingRatio() external view returns (uint256) {
        uint256 pcvUsd = treasury.totalReserves();
        uint256 supply = dre.totalSupply();
        return (supply == 0) ? 0 : (pcvUsd * 1e18) / supply; // 1e18 == β=1
    }

    function projectedEpochRate() public view returns (uint256 apr, uint256 epochRate, uint256 backingRatio) {
        uint256 pcvUsd = treasury.totalReserves();
        uint256 supply = dre.totalSupply();
        return projectedEpochRateRaw(pcvUsd, supply);
    }

    function projectedEpochRateRaw(uint256 pcvUsd, uint256 supply)
        public
        pure
        returns (uint256 apr, uint256 epochRate, uint256 backingRatio)
    {
        if (supply == 0) return (0, 0, 0);

        backingRatio = (pcvUsd * 1e18) / supply;
        uint256 beta1e2 = backingRatio / 1e16;

        if (beta1e2 < 100) {
            apr = 0;
        } else if (beta1e2 < 150) {
            apr = (beta1e2 - 100) * K1;
        } else if (beta1e2 < 250) {
            apr = FLOOR_APR + ((beta1e2 - 150) * K2) / 100;
            if (apr > CEIL_APR) apr = CEIL_APR;
        } else {
            apr = CEIL_APR;
        }

        uint256 epochsPerYear = 365 days / EPOCH;
        epochRate = (apr * 1e18) / (100 * epochsPerYear);
    }
}
