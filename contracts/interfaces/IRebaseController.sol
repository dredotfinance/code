// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "./IDRE.sol";
import "./IDreTreasury.sol";
import "./IDreStaking.sol";

interface IRebaseController {
    // --- Events --------------------------------------------------------------
    event Rebased(uint256 backingRatio, uint256 epochRate, uint256 tokensMinted);

    // --- State Variables -----------------------------------------------------
    function dre() external view returns (IDRE);
    function treasury() external view returns (IDreTreasury);
    function staking() external view returns (IDreStaking);
    function EPOCH() external view returns (uint256);
    function lastEpochTime() external view returns (uint256);
    function K1() external view returns (uint16);
    function K2() external view returns (uint16);
    function FLOOR_APR() external view returns (uint16);
    function CEIL_APR() external view returns (uint16);

    // --- Functions ----------------------------------------------------------
    function initialize(address _dre, address _treasury, address _staking, address _authority) external;

    function executeEpoch() external;

    function currentBackingRatio() external view returns (uint256);

    function projectedEpochRate() external view returns (uint256 apr, uint256 epochRate, uint256 backingRatio);

    function projectedEpochRateRaw(uint256 pcvUsd, uint256 supply)
        external
        pure
        returns (uint256 apr, uint256 epochRate, uint256 backingRatio);
}
