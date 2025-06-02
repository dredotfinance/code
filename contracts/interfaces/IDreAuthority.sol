// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "./ITreasury.sol";

interface IDreAuthority {
    /* ========== EVENTS ========== */

    event TreasuryUpdated(address indexed newTreasury, address indexed oldTreasury);
    event OperationsTreasuryUpdated(address indexed newOperationsTreasury, address indexed oldOperationsTreasury);

    function addGovernor(address _newGovernor) external;
    function addGuardian(address _newGuardian) external;
    function addPolicy(address _newPolicy) external;
    function addRewardManager(address _newRewardManager) external;
    function addReserveManager(address _newReserveManager) external;

    function isGovernor(address account) external view returns (bool);

    function isGuardian(address account) external view returns (bool);

    function isPolicy(address account) external view returns (bool);

    function isVault(address account) external view returns (bool);

    function isTreasury(address account) external view returns (bool);

    function isReserveManager(address account) external view returns (bool);

    function isRewardManager(address account) external view returns (bool);

    function isReserveDepositor(address account) external view returns (bool);

    function operationsTreasury() external view returns (address);

    function treasury() external view returns (ITreasury);
}
