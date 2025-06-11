// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "./IAppTreasury.sol";

interface IAppAuthority {
    /* ========== EVENTS ========== */

    event TreasuryUpdated(address indexed newTreasury, address indexed oldTreasury);
    event OperationsTreasuryUpdated(address indexed newOperationsTreasury, address indexed oldOperationsTreasury);

    function addGovernor(address _newGovernor) external;
    function addGuardian(address _newGuardian) external;
    function addPolicy(address _newPolicy) external;
    function addRewardManager(address _newRewardManager) external;
    function addReserveManager(address _newReserveManager) external;
    function addExecutor(address _newExecutor) external;
    function addBondManager(address _newBondManager) external;

    function removeGovernor(address _oldGovernor) external;
    function removeGuardian(address _oldGuardian) external;
    function removePolicy(address _oldPolicy) external;
    function removeRewardManager(address _oldRewardManager) external;
    function removeReserveManager(address _oldReserveManager) external;
    function removeExecutor(address _oldExecutor) external;
    function removeVault(address _oldVault) external;
    function removeBondManager(address _oldBondManager) external;

    function isGovernor(address account) external view returns (bool);

    function isBondManager(address account) external view returns (bool);

    function isGuardian(address account) external view returns (bool);

    function isPolicy(address account) external view returns (bool);

    function isVault(address account) external view returns (bool);

    function isExecutor(address account) external view returns (bool);

    function isTreasury(address account) external view returns (bool);

    function isReserveManager(address account) external view returns (bool);

    function isRewardManager(address account) external view returns (bool);

    function isReserveDepositor(address account) external view returns (bool);

    function operationsTreasury() external view returns (address);

    function treasury() external view returns (IAppTreasury);
}
