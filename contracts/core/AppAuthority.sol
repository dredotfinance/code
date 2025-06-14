// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "../interfaces/IAppAuthority.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract AppAuthority is IAppAuthority, AccessControlEnumerable {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant POLICY_ROLE = keccak256("POLICY_ROLE");
    bytes32 public constant RESERVE_MANAGER_ROLE = keccak256("RESERVE_MANAGER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant RESERVE_DEPOSITOR_ROLE = keccak256("RESERVE_DEPOSITOR_ROLE");
    bytes32 public constant BOND_MANAGER_ROLE = keccak256("BOND_MANAGER_ROLE");

    /// @inheritdoc IAppAuthority
    address public override operationsTreasury;

    /// @inheritdoc IAppAuthority
    IAppTreasury public override treasury;

    constructor() {
        _grantRole(GOVERNOR_ROLE, msg.sender);

        _setRoleAdmin(GOVERNOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(BOND_MANAGER_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(GUARDIAN_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(POLICY_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(RESERVE_DEPOSITOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(RESERVE_MANAGER_ROLE, GOVERNOR_ROLE);
    }

    modifier onlyGovernor() {
        require(hasRole(GOVERNOR_ROLE, msg.sender), "Only governor");
        _;
    }

    /// @inheritdoc IAppAuthority
    function setOperationsTreasury(address _newOperationsTreasury) external onlyGovernor {
        address oldOperationsTreasury = operationsTreasury;
        operationsTreasury = _newOperationsTreasury;
        emit OperationsTreasuryUpdated(_newOperationsTreasury, oldOperationsTreasury);
    }

    /// @inheritdoc IAppAuthority
    function setTreasury(address _newTreasury) external onlyGovernor {
        address oldTreasury = address(treasury);
        treasury = IAppTreasury(_newTreasury);
        emit TreasuryUpdated(_newTreasury, oldTreasury);
    }

    /// @inheritdoc IAppAuthority
    function addGovernor(address _newGovernor) external onlyGovernor {
        _grantRole(GOVERNOR_ROLE, _newGovernor);
    }

    /// @inheritdoc IAppAuthority
    function addGuardian(address _newGuardian) external onlyGovernor {
        _grantRole(GUARDIAN_ROLE, _newGuardian);
    }

    /// @inheritdoc IAppAuthority
    function addPolicy(address _newPolicy) external onlyGovernor {
        _grantRole(POLICY_ROLE, _newPolicy);
    }

    /// @inheritdoc IAppAuthority
    function addReserveManager(address _newReserveManager) external onlyGovernor {
        _grantRole(RESERVE_MANAGER_ROLE, _newReserveManager);
    }

    /// @inheritdoc IAppAuthority
    function addReserveDepositor(address _newReserveDepositor) external onlyGovernor {
        _grantRole(RESERVE_DEPOSITOR_ROLE, _newReserveDepositor);
    }

    /// @inheritdoc IAppAuthority
    function addBondManager(address _newBondManager) external onlyGovernor {
        _grantRole(BOND_MANAGER_ROLE, _newBondManager);
    }

    /// @inheritdoc IAppAuthority
    function addExecutor(address _newExecutor) external onlyGovernor {
        _grantRole(EXECUTOR_ROLE, _newExecutor);
    }

    /// @inheritdoc IAppAuthority
    function removeGovernor(address _oldGovernor) external onlyGovernor {
        _revokeRole(GOVERNOR_ROLE, _oldGovernor);
    }

    /// @inheritdoc IAppAuthority
    function removeGuardian(address _oldGuardian) external onlyGovernor {
        _revokeRole(GUARDIAN_ROLE, _oldGuardian);
    }

    /// @inheritdoc IAppAuthority
    function removePolicy(address _oldPolicy) external onlyGovernor {
        _revokeRole(POLICY_ROLE, _oldPolicy);
    }

    /// @inheritdoc IAppAuthority
    function removeReserveManager(address _oldReserveManager) external onlyGovernor {
        _revokeRole(RESERVE_MANAGER_ROLE, _oldReserveManager);
    }

    /// @inheritdoc IAppAuthority
    function removeReserveDepositor(address _oldReserveDepositor) external onlyGovernor {
        _revokeRole(RESERVE_DEPOSITOR_ROLE, _oldReserveDepositor);
    }

    /// @inheritdoc IAppAuthority
    function removeExecutor(address _oldExecutor) external onlyGovernor {
        _revokeRole(EXECUTOR_ROLE, _oldExecutor);
    }

    /// @inheritdoc IAppAuthority
    function removeBondManager(address _oldBondManager) external onlyGovernor {
        _revokeRole(BOND_MANAGER_ROLE, _oldBondManager);
    }

    /* ========== VIEWS ========== */

    /// @inheritdoc IAppAuthority
    function isGovernor(address account) external view override returns (bool) {
        return hasRole(GOVERNOR_ROLE, account);
    }

    /// @inheritdoc IAppAuthority
    function isReserveDepositor(address account) external view override returns (bool) {
        return hasRole(RESERVE_DEPOSITOR_ROLE, account);
    }

    /// @inheritdoc IAppAuthority
    function isReserveManager(address account) external view override returns (bool) {
        return hasRole(RESERVE_MANAGER_ROLE, account);
    }

    /// @inheritdoc IAppAuthority
    function isGuardian(address account) external view override returns (bool) {
        return hasRole(GUARDIAN_ROLE, account);
    }

    /// @inheritdoc IAppAuthority
    function isPolicy(address account) external view override returns (bool) {
        return hasRole(POLICY_ROLE, account);
    }

    /// @inheritdoc IAppAuthority
    function isTreasury(address account) external view override returns (bool) {
        return account == address(treasury);
    }

    /// @inheritdoc IAppAuthority
    function isExecutor(address account) external view override returns (bool) {
        return hasRole(EXECUTOR_ROLE, account);
    }

    /// @inheritdoc IAppAuthority
    function isBondManager(address account) external view override returns (bool) {
        return hasRole(BOND_MANAGER_ROLE, account);
    }

    /// @inheritdoc IAppAuthority
    function getAllCandidates(bytes32 role) public view returns (address[] memory candidates) {
        uint256 count = getRoleMemberCount(role);
        candidates = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            candidates[i] = getRoleMember(role, i);
        }
    }

    /// @inheritdoc IAppAuthority
    function getAllReserveDepositorCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(RESERVE_DEPOSITOR_ROLE);
    }

    /// @inheritdoc IAppAuthority
    function getAllExecutorCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(EXECUTOR_ROLE);
    }

    /// @inheritdoc IAppAuthority
    function getAllPolicyCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(POLICY_ROLE);
    }

    /// @inheritdoc IAppAuthority
    function getAllReserveManagerCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(RESERVE_MANAGER_ROLE);
    }

    /// @inheritdoc IAppAuthority
    function getAllGuardianCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(GUARDIAN_ROLE);
    }

    /// @inheritdoc IAppAuthority
    function getAllGovernorCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(GOVERNOR_ROLE);
    }

    /// @inheritdoc IAppAuthority
    function getAllBondManagerCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(BOND_MANAGER_ROLE);
    }
}
