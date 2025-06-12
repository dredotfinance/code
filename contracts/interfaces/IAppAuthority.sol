// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "./IAppTreasury.sol";

/// @title IAppAuthority
/// @notice Interface for managing different roles and authorities in the application
/// @dev This interface defines the core access control functionality for the application, including role management,
/// treasury management, and candidate tracking for various roles in the system
interface IAppAuthority {
    /// @notice Emitted when the treasury address is updated
    /// @param newTreasury The address of the new treasury
    /// @param oldTreasury The address of the old treasury
    event TreasuryUpdated(address indexed newTreasury, address indexed oldTreasury);

    /// @notice Emitted when the operations treasury address is updated
    /// @param newOperationsTreasury The address of the new operations treasury
    /// @param oldOperationsTreasury The address of the old operations treasury
    event OperationsTreasuryUpdated(address indexed newOperationsTreasury, address indexed oldOperationsTreasury);

    /// @notice Adds a new governor to the system
    /// @param _newGovernor The address of the new governor to add
    function addGovernor(address _newGovernor) external;

    /// @notice Adds a new guardian to the system
    /// @param _newGuardian The address of the new guardian to add
    function addGuardian(address _newGuardian) external;

    /// @notice Adds a new policy to the system
    /// @param _newPolicy The address of the new policy to add
    function addPolicy(address _newPolicy) external;

    /// @notice Adds a new reserve manager to the system
    /// @param _newReserveManager The address of the new reserve manager to add
    function addReserveManager(address _newReserveManager) external;

    /// @notice Adds a new executor to the system
    /// @param _newExecutor The address of the new executor to add
    function addExecutor(address _newExecutor) external;

    /// @notice Adds a new bond manager to the system
    /// @param _newBondManager The address of the new bond manager to add
    function addBondManager(address _newBondManager) external;

    /// @notice Adds a new reserve depositor to the system
    /// @param _newReserveDepositor The address of the new reserve depositor to add
    function addReserveDepositor(address _newReserveDepositor) external;

    /// @notice Removes an existing governor from the system
    /// @param _oldGovernor The address of the governor to remove
    function removeGovernor(address _oldGovernor) external;

    /// @notice Removes an existing guardian from the system
    /// @param _oldGuardian The address of the guardian to remove
    function removeGuardian(address _oldGuardian) external;

    /// @notice Removes an existing policy from the system
    /// @param _oldPolicy The address of the policy to remove
    function removePolicy(address _oldPolicy) external;

    /// @notice Removes an existing reserve manager from the system
    /// @param _oldReserveManager The address of the reserve manager to remove
    function removeReserveManager(address _oldReserveManager) external;

    /// @notice Removes an existing executor from the system
    /// @param _oldExecutor The address of the executor to remove
    function removeExecutor(address _oldExecutor) external;

    /// @notice Removes an existing bond manager from the system
    /// @param _oldBondManager The address of the bond manager to remove
    function removeBondManager(address _oldBondManager) external;

    /// @notice Sets the operations treasury address
    /// @param _newOperationsTreasury The address of the new operations treasury
    function setOperationsTreasury(address _newOperationsTreasury) external;

    /// @notice Sets the treasury address
    /// @param _newTreasury The address of the new treasury
    function setTreasury(address _newTreasury) external;

    /// @notice Removes an existing reserve depositor from the system
    /// @param _oldReserveDepositor The address of the reserve depositor to remove
    function removeReserveDepositor(address _oldReserveDepositor) external;

    /// @notice Checks if an address is a governor
    /// @param account The address to check
    /// @return bool True if the address is a governor, false otherwise
    function isGovernor(address account) external view returns (bool);

    /// @notice Checks if an address is a bond manager
    /// @param account The address to check
    /// @return bool True if the address is a bond manager, false otherwise
    function isBondManager(address account) external view returns (bool);

    /// @notice Checks if an address is a guardian
    /// @param account The address to check
    /// @return bool True if the address is a guardian, false otherwise
    function isGuardian(address account) external view returns (bool);

    /// @notice Checks if an address is a policy
    /// @param account The address to check
    /// @return bool True if the address is a policy, false otherwise
    function isPolicy(address account) external view returns (bool);

    /// @notice Checks if an address is an executor
    /// @param account The address to check
    /// @return bool True if the address is an executor, false otherwise
    function isExecutor(address account) external view returns (bool);

    /// @notice Checks if an address is the treasury
    /// @param account The address to check
    /// @return bool True if the address is the treasury, false otherwise
    function isTreasury(address account) external view returns (bool);

    /// @notice Checks if an address is a reserve manager
    /// @param account The address to check
    /// @return bool True if the address is a reserve manager, false otherwise
    function isReserveManager(address account) external view returns (bool);

    /// @notice Checks if an address is a reserve depositor
    /// @param account The address to check
    /// @return bool True if the address is a reserve depositor, false otherwise
    function isReserveDepositor(address account) external view returns (bool);

    /// @notice Returns the address of the operations treasury
    /// @return address The address of the operations treasury
    function operationsTreasury() external view returns (address);

    /// @notice Returns the treasury contract instance
    /// @return IAppTreasury The treasury contract instance
    function treasury() external view returns (IAppTreasury);

    /// @notice Returns an array of all candidates for a given role
    /// @param role The role to get candidates for (e.g., GOVERNOR_ROLE, GUARDIAN_ROLE, etc.)
    /// @return candidates Array of addresses that are candidates for the given role
    function getAllCandidates(bytes32 role) external view returns (address[] memory candidates);

    /// @notice Returns an array of all reserve depositor candidates
    /// @return candidates Array of addresses that are reserve depositor candidates
    function getAllReserveDepositorCandidates() external view returns (address[] memory candidates);

    /// @notice Returns an array of all executor candidates
    /// @return candidates Array of addresses that are executor candidates
    function getAllExecutorCandidates() external view returns (address[] memory candidates);

    /// @notice Returns an array of all policy candidates
    /// @return candidates Array of addresses that are policy candidates
    function getAllPolicyCandidates() external view returns (address[] memory candidates);

    /// @notice Returns an array of all reserve manager candidates
    /// @return candidates Array of addresses that are reserve manager candidates
    function getAllReserveManagerCandidates() external view returns (address[] memory candidates);

    /// @notice Returns an array of all guardian candidates
    /// @return candidates Array of addresses that are guardian candidates
    function getAllGuardianCandidates() external view returns (address[] memory candidates);

    /// @notice Returns an array of all governor candidates
    /// @return candidates Array of addresses that are governor candidates
    function getAllGovernorCandidates() external view returns (address[] memory candidates);

    /// @notice Returns an array of all bond manager candidates
    /// @return candidates Array of addresses that are bond manager candidates
    function getAllBondManagerCandidates() external view returns (address[] memory candidates);
}
