// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IDRE.sol";
import "./interfaces/IDreTreasury.sol";
import "./interfaces/IDreStaking.sol";
import "./interfaces/IDreOracle.sol";
import "./interfaces/IRebaseController.sol";
import "./libraries/StakingDistributionLogic.sol";
import "./libraries/YieldLogic.sol";
import "./DreAccessControlled.sol";

/**
 * @title BondController
 * @dev Minimal reference implementation of DRE's bonding-curve logic.
 *      ─ Calculates backing ratio β = PCV / supply
 *      ─ Determines epochic rebase rate r_t using piece-wise curve
 *      ─ Mints DRE supply for stakers each epoch once called by a keeper
 *      ─ Exposes view helpers for front-end gauges
 */
contract RebaseController is DreAccessControlled, IRebaseController {
    IDRE public dre; // DRE token (decimals = 18)
    IDreTreasury public treasury;
    IDreStaking public staking; // staking contract or escrow
    IDreOracle public oracle; // price oracle

    // --- Epoch params --------------------------------------------------------
    uint256 public immutable EPOCH = 8 hours;
    uint256 public lastEpochTime;

    uint256 public targetOpsPct; // 10 %
    uint256 public targetFloorPct; // 15 %
    uint256 public targetStakerPct; // 50 %

    function initialize(address _dre, address _treasury, address _staking, address _oracle, address _authority)
        public
        initializer
    {
        dre = IDRE(_dre);
        treasury = IDreTreasury(_treasury);
        staking = IDreStaking(_staking);
        oracle = IDreOracle(_oracle);
        lastEpochTime = block.timestamp;
        __DreAccessControlled_init(_authority);

        dre.approve(address(staking), type(uint256).max);
    }

    function setTargetPcts(uint256 _targetOpsPct, uint256 _targetFloorPct, uint256 _targetStakerPct)
        external
        onlyGovernor
    {
        targetOpsPct = _targetOpsPct;
        targetFloorPct = _targetFloorPct;
        targetStakerPct = _targetStakerPct;
        require(targetOpsPct + targetFloorPct + targetStakerPct == 1e18, "Invalid percentages");
    }

    // --- Public keeper call --------------------------------------------------
    function executeEpoch() external onlyExecutor {
        require(block.timestamp >= lastEpochTime + EPOCH, "epoch not ready");

        treasury.syncReserves();

        // Get current state
        (uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 newFloorPrice) = projectedMint();

        // Verify we have enough reserves
        require(epochMint <= treasury.excessReserves(), "Insufficient reserves");

        if (epochMint > 0) {
            // Mint tokens
            dre.mint(address(this), toStakers + toOps);

            // Distribute to stakers
            staking.notifyRewardAmount(toStakers);

            // Send to ops treasury
            dre.transfer(address(authority.operationsTreasury()), toOps);

            // Update oracle floor price
            oracle.setDrePrice(newFloorPrice);
        }

        lastEpochTime = block.timestamp;
        emit Rebased(epochMint, toStakers, toOps, newFloorPrice);
    }

    // --- View helpers --------------------------------------------------------
    function currentBackingRatio() external view returns (uint256) {
        uint256 pcv = treasury.totalReserves();
        uint256 supply = dre.totalSupply();
        return (supply == 0) ? 0 : (pcv * 1e18) / supply; // 1e18 == β=1
    }

    function projectedMint()
        public
        view
        returns (uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 newFloorPrice)
    {
        // Get current state
        uint256 pcv = treasury.totalReserves();
        uint256 supply = dre.totalSupply();
        uint256 stakedSupply = staking.totalStaked();
        uint256 currentFloorPrice = oracle.getDrePrice();

        // Calculate APR and epoch rate
        (, epochMint, toStakers, toOps, newFloorPrice) =
            projectedEpochRateRaw(pcv, supply, currentFloorPrice, stakedSupply);
    }

    function projectedEpochRate()
        public
        view
        returns (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 newFloorPrice)
    {
        uint256 pcv = treasury.calculateReserves();
        uint256 supply = dre.totalSupply();
        return projectedEpochRateRaw(pcv, supply, oracle.getDrePrice(), staking.totalStaked());
    }

    function projectedEpochRateRaw(uint256 pcv, uint256 supply, uint256 currentFloorPrice, uint256 stakedSupply)
        public
        pure
        returns (uint256 apr, uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 newFloorPrice)
    {
        // Calculate APR and epoch rate
        (apr, epochMint) = YieldLogic.calcEpoch(pcv, supply, 365 days / EPOCH);

        // Calculate token distribution
        (toStakers, toOps, newFloorPrice) =
            StakingDistributionLogic.allocate(epochMint, supply, stakedSupply, currentFloorPrice);
    }
}
