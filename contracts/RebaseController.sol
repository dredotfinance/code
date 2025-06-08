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
    address public burner; // burner contract

    // --- Epoch params --------------------------------------------------------
    uint256 public immutable EPOCH = 8 hours;
    uint256 public lastEpochTime;

    uint256 public targetOpsPct; // ideally 10%
    uint256 public minFloorPct; // minimum to the floor price ideally 15%
    uint256 public maxFloorPct; // maximum to the floor price ideally 50%
    uint256 public floorSlope; // ideally 50%

    function initialize(
        address _dre,
        address _treasury,
        address _staking,
        address _oracle,
        address _authority,
        address _burner
    ) public initializer {
        dre = IDRE(_dre);
        treasury = IDreTreasury(_treasury);
        staking = IDreStaking(_staking);
        oracle = IDreOracle(_oracle);
        burner = _burner;
        __DreAccessControlled_init(_authority);

        dre.approve(address(staking), type(uint256).max);
    }

    function setTargetPcts(uint256 _targetOpsPct, uint256 _minFloorPct, uint256 _maxFloorPct, uint256 _floorSlope)
        external
        onlyGovernor
    {
        targetOpsPct = _targetOpsPct;
        minFloorPct = _minFloorPct;
        maxFloorPct = _maxFloorPct;
        floorSlope = _floorSlope;
        emit TargetPctsSet(targetOpsPct, minFloorPct, maxFloorPct, floorSlope);
    }

    // --- Public keeper call --------------------------------------------------
    function executeEpoch() external onlyExecutor {
        require(block.timestamp >= lastEpochTime + EPOCH, "epoch not ready");

        treasury.syncReserves();

        // Get current state
        (, uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 toBurner) = projectedEpochRate();

        // Verify we have enough reserves
        require(epochMint <= treasury.excessReserves(), "Insufficient reserves");

        if (epochMint > 0) {
            // Mint tokens
            dre.mint(address(this), epochMint);

            // Distribute to stakers
            staking.notifyRewardAmount(toStakers);

            // Send to ops treasury
            dre.transfer(address(authority.operationsTreasury()), toOps);

            // Send to burner
            dre.transfer(burner, toBurner);
        }

        lastEpochTime = block.timestamp;
        emit Rebased(epochMint, toStakers, toOps, toBurner);
    }

    // --- View helpers --------------------------------------------------------
    function currentBackingRatio() external view returns (uint256) {
        uint256 pcv = treasury.totalReserves();
        uint256 supply = treasury.totalSupply();
        return (supply == 0) ? 0 : (pcv * 1e18) / supply; // 1e18 == β=1
    }

    function projectedEpochRate()
        public
        view
        returns (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 toBurner)
    {
        uint256 pcv = treasury.totalReserves();
        uint256 supply = treasury.totalSupply();
        return projectedEpochRateRaw(pcv, supply, staking.totalStaked());
    }

    function projectedEpochRateRaw(uint256 pcv, uint256 supply, uint256 stakedSupply)
        public
        view
        returns (uint256 apr, uint256 epochMint, uint256 toStakers, uint256 toOps, uint256 toBurner)
    {
        require(targetOpsPct + minFloorPct + maxFloorPct > 0, "Invalid percentages");

        // Calculate APR and epoch rate
        (apr, epochMint) = YieldLogic.calcEpoch(pcv, supply, 365 days / EPOCH);

        // Calculate token distribution
        (toStakers, toOps, toBurner) = StakingDistributionLogic.allocate(
            epochMint, supply, stakedSupply, targetOpsPct, minFloorPct, maxFloorPct, floorSlope
        );
    }
}
