// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./IDreTreasury.sol";

/// @title IDreAuthority
/// @notice Interface for the DRE Authority contract that manages roles and permissions
/// @dev Handles role management for various system components including governors, guardians, policies, and executors
interface IDreAuthority {
    /* ========== EVENTS ========== */

    /// @notice Emitted when the treasury address is updated
    /// @param newTreasury Address of the new treasury
    /// @param oldTreasury Address of the old treasury
    event TreasuryUpdated(address indexed newTreasury, address indexed oldTreasury);

    /// @notice Emitted when the operations treasury address is updated
    /// @param newOperationsTreasury Address of the new operations treasury
    /// @param oldOperationsTreasury Address of the old operations treasury
    event OperationsTreasuryUpdated(address indexed newOperationsTreasury, address indexed oldOperationsTreasury);

    /* ========== ROLE MANAGEMENT ========== */

    /// @notice Adds a new governor to the system
    /// @param _newGovernor Address of the new governor
    function addGovernor(address _newGovernor) external;

    /// @notice Adds a new guardian to the system
    /// @param _newGuardian Address of the new guardian
    function addGuardian(address _newGuardian) external;

    /// @notice Adds a new policy to the system
    /// @param _newPolicy Address of the new policy
    function addPolicy(address _newPolicy) external;

    /// @notice Adds a new reward manager to the system
    /// @param _newRewardManager Address of the new reward manager
    function addRewardManager(address _newRewardManager) external;

    /// @notice Adds a new reserve manager to the system
    /// @param _newReserveManager Address of the new reserve manager
    function addReserveManager(address _newReserveManager) external;

    /// @notice Adds a new executor to the system
    /// @param _newExecutor Address of the new executor
    function addExecutor(address _newExecutor) external;

    /// @notice Adds a new bond manager to the system
    /// @param _newBondManager Address of the new bond manager
    function addBondManager(address _newBondManager) external;

    /// @notice Removes an existing governor from the system
    /// @param _oldGovernor Address of the governor to remove
    function removeGovernor(address _oldGovernor) external;

    /// @notice Removes an existing guardian from the system
    /// @param _oldGuardian Address of the guardian to remove
    function removeGuardian(address _oldGuardian) external;

    /// @notice Removes an existing policy from the system
    /// @param _oldPolicy Address of the policy to remove
    function removePolicy(address _oldPolicy) external;

    /// @notice Removes an existing reward manager from the system
    /// @param _oldRewardManager Address of the reward manager to remove
    function removeRewardManager(address _oldRewardManager) external;

    /// @notice Removes an existing reserve manager from the system
    /// @param _oldReserveManager Address of the reserve manager to remove
    function removeReserveManager(address _oldReserveManager) external;

    /// @notice Removes an existing executor from the system
    /// @param _oldExecutor Address of the executor to remove
    function removeExecutor(address _oldExecutor) external;

    /// @notice Removes an existing vault from the system
    /// @param _oldVault Address of the vault to remove
    function removeVault(address _oldVault) external;

    /// @notice Removes an existing bond manager from the system
    /// @param _oldBondManager Address of the bond manager to remove
    function removeBondManager(address _oldBondManager) external;

    /* ========== ROLE CHECKING ========== */

    /// @notice Checks if an address is a governor
    /// @param account Address to check
    /// @return bool True if the address is a governor
    function isGovernor(address account) external view returns (bool);

    /// @notice Checks if an address is a guardian
    /// @param account Address to check
    /// @return bool True if the address is a guardian
    function isGuardian(address account) external view returns (bool);

    /// @notice Checks if an address is a policy
    /// @param account Address to check
    /// @return bool True if the address is a policy
    function isPolicy(address account) external view returns (bool);

    /// @notice Checks if an address is a vault
    /// @param account Address to check
    /// @return bool True if the address is a vault
    function isVault(address account) external view returns (bool);

    /// @notice Checks if an address is an executor
    /// @param account Address to check
    /// @return bool True if the address is an executor
    function isExecutor(address account) external view returns (bool);

    /// @notice Checks if an address is the treasury
    /// @param account Address to check
    /// @return bool True if the address is the treasury
    function isTreasury(address account) external view returns (bool);

    /// @notice Checks if an address is a reserve manager
    /// @param account Address to check
    /// @return bool True if the address is a reserve manager
    function isReserveManager(address account) external view returns (bool);

    /// @notice Checks if an address is a reward manager
    /// @param account Address to check
    /// @return bool True if the address is a reward manager
    function isRewardManager(address account) external view returns (bool);

    /// @notice Checks if an address is a reserve depositor
    /// @param account Address to check
    /// @return bool True if the address is a reserve depositor
    function isReserveDepositor(address account) external view returns (bool);

    /// @notice Checks if an address is a bond manager
    /// @param account Address to check
    /// @return bool True if the address is a bond manager
    function isBondManager(address account) external view returns (bool);

    /* ========== GETTERS ========== */

    /// @notice Gets the operations treasury address
    /// @return address The operations treasury address
    function operationsTreasury() external view returns (address);

    /// @notice Gets the treasury contract
    /// @return IDreTreasury The treasury contract
    function treasury() external view returns (IDreTreasury);
}
