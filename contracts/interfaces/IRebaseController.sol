// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "./IApp.sol";
import "./IAppTreasury.sol";
import "./IAppStaking.sol";

interface IRebaseController {
    // --- State Variables -----------------------------------------------------
    function app() external view returns (IApp);
    function treasury() external view returns (IAppTreasury);
    function staking() external view returns (IAppStaking);
    function EPOCH() external view returns (uint256);
    function lastEpochTime() external view returns (uint256);

    // --- Events --------------------------------------------------------------
    event Rebased(uint256 backingRatio, uint256 epochRate, uint256 tokensMinted, uint256 newFloorPrice);
    event TargetPctsSet(uint256 targetOpsPct, uint256 minFloorPct, uint256 maxFloorPct, uint256 floorSlope);
    event AprVariablesSet(uint16 floorApr, uint16 ceilApr, uint16 k1, uint16 k2);

    // --- Functions ----------------------------------------------------------
    function initialize(address _dre, address _treasury, address _staking, address _authority, address _burner)
        external;

    function executeEpoch() external;

    function currentBackingRatio() external view returns (uint256);

    function projectedEpochRate()
        external
        view
        returns (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 toBurner);

    function projectedEpochRateRaw(uint256 pcv, uint256 supply, uint256 stakedSupply)
        external
        view
        returns (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 toBurner);
}
