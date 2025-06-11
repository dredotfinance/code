// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IApp.sol";
import "./interfaces/IAppTreasury.sol";
import "./interfaces/IAppStaking.sol";
import "./interfaces/IAppOracle.sol";
import "./interfaces/IRebaseController.sol";
import "./libraries/StakingDistributionLogic.sol";
import "./libraries/YieldLogic.sol";
import "./AppAccessControlled.sol";

/**
 * @title BondController
 * @dev Minimal reference implementation of App's bonding-curve logic.
 *      ─ Calculates backing ratio β = PCV / supply
 *      ─ Determines epochic rebase rate r_t using piece-wise curve
 *      ─ Mints App supply for stakers each epoch once called by a keeper
 *      ─ Exposes view helpers for front-end gauges
 */
contract RebaseController is AppAccessControlled, IRebaseController {
    IApp public app; // App token (decimals = 18)
    IAppTreasury public treasury;
    IAppStaking public staking; // staking contract or escrow
    IAppOracle public oracle; // price oracle
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
        app = IApp(_dre);
        treasury = IAppTreasury(_treasury);
        staking = IAppStaking(_staking);
        oracle = IAppOracle(_oracle);
        burner = _burner;
        __AppAccessControlled_init(_authority);

        app.approve(address(staking), type(uint256).max);
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
            app.mint(address(this), epochMint);

            // Distribute to stakers
            staking.notifyRewardAmount(toStakers);

            // Send to ops treasury
            app.transfer(address(authority.operationsTreasury()), toOps);

            // Send to burner
            app.transfer(burner, toBurner);
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
        uint256 pcv = treasury.calculateReserves();
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
