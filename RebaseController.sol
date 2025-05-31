// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IDRE.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IDreStaking.sol";
import "./DreAccessControlled.sol";

contract RebaseController is DreAccessControlled, ReentrancyGuard, Pausable {
    IDRE public DRE;
    ITreasury public treasury;
    IDreStaking public staking;

    uint256 public epochLength;
    uint256 public nextEpochTime;
    uint256 public lastEpochTime;
    uint256 public epochRate;
    uint256 public constant RATE_PRECISION = 1e6;

    event EpochExecuted(uint256 epochTime, uint256 epochRate);
    event EpochRateUpdated(uint256 newRate);
    event EpochLengthUpdated(uint256 newLength);

    constructor(address _dre, address _treasury, address _staking, uint256 _epochLength, address _authority) DreAccessControlled(_authority) {
        require(_dre != address(0), "Zero address: DRE");
        require(_treasury != address(0), "Zero address: Treasury");
        require(_staking != address(0), "Zero address: Staking");
        require(_epochLength > 0, "Invalid epoch length");

        DRE = IDRE(_dre);
        treasury = ITreasury(_treasury);
        staking = IDreStaking(_staking);
        epochLength = _epochLength;
        nextEpochTime = block.timestamp.add(_epochLength);
        lastEpochTime = block.timestamp;

        __DreAccessControlled_init(_authority);
    }

    function executeEpoch() external nonReentrant whenNotPaused {
        require(block.timestamp >= nextEpochTime, "RebaseController: epoch not ready");
        require(epochRate > 0, "RebaseController: invalid epoch rate");

        uint256 currentTime = block.timestamp;
        uint256 timeElapsed = currentTime.sub(lastEpochTime);
        uint256 rewardAmount = DRE.totalSupply().mul(epochRate).mul(timeElapsed).div(RATE_PRECISION).div(365 days);

        if (rewardAmount > 0) {
            DRE.mint(address(staking), rewardAmount);
            staking.distributeRewards(rewardAmount);
        }

        lastEpochTime = currentTime;
        nextEpochTime = currentTime.add(epochLength);

        emit EpochExecuted(currentTime, epochRate);
    }

    function setEpochRate(uint256 _newRate) external onlyGovernor {
        require(_newRate <= RATE_PRECISION, "RebaseController: rate too high");
        epochRate = _newRate;
        emit EpochRateUpdated(_newRate);
    }

    function setEpochLength(uint256 _newLength) external onlyGovernor {
        require(_newLength > 0, "RebaseController: invalid length");
        epochLength = _newLength;
        emit EpochLengthUpdated(_newLength);
    }

    function pause() external onlyGuardian {
        _pause();
    }

    function unpause() external onlyGuardian {
        _unpause();
    }

    function projectedEpochRate() public view returns (uint256) {
        uint256 backingRatio = treasury.excessReserves().mul(RATE_PRECISION).div(DRE.totalSupply());
        if (backingRatio >= RATE_PRECISION) {
            return RATE_PRECISION;
        } else if (backingRatio >= RATE_PRECISION.mul(90).div(100)) {
            return RATE_PRECISION.mul(95).div(100);
        } else if (backingRatio >= RATE_PRECISION.mul(80).div(100)) {
            return RATE_PRECISION.mul(90).div(100);
        } else {
            return RATE_PRECISION.mul(85).div(100);
        }
    }
}
