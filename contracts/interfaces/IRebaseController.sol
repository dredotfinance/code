// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "./IDRE.sol";
import "./IDreTreasury.sol";
import "./IDreStaking.sol";

interface IRebaseController {
    // --- State Variables -----------------------------------------------------
    function dre() external view returns (IDRE);
    function treasury() external view returns (IDreTreasury);
    function staking() external view returns (IDreStaking);
    function EPOCH() external view returns (uint256);
    function lastEpochTime() external view returns (uint256);

    // --- Events --------------------------------------------------------------
    event Rebased(uint256 backingRatio, uint256 epochRate, uint256 tokensMinted, uint256 newFloorPrice);
    event TargetPctsSet(uint256 targetOpsPct, uint256 minFloorPct, uint256 maxFloorPct, uint256 floorSlope);

    // --- Functions ----------------------------------------------------------
    function initialize(address _dre, address _treasury, address _staking, address _oracle, address _authority)
        external;

    function executeEpoch() external;

    function currentBackingRatio() external view returns (uint256);

    function projectedEpochRate()
        external
        view
        returns (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 newFloorPrice);

    function projectedEpochRateRaw(uint256 pcv, uint256 supply, uint256 currentFloorPrice, uint256 stakedSupply)
        external
        view
        returns (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 newFloorPrice);
}
