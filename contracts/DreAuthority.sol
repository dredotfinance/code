// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "./interfaces/IDreAuthority.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract DreAuthority is IDreAuthority, AccessControlEnumerable {
    /* ========== STATE VARIABLES ========== */

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant POLICY_ROLE = keccak256("POLICY_ROLE");
    bytes32 public constant RESERVE_MANAGER_ROLE = keccak256("RESERVE_MANAGER_ROLE");
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    bytes32 public constant RESERVE_DEPOSITOR_ROLE = keccak256("RESERVE_DEPOSITOR_ROLE");

    address public override operationsTreasury;
    IDreTreasury public override treasury;

    /* ========== Constructor ========== */

    constructor() {
        _grantRole(GOVERNOR_ROLE, msg.sender);

        _setRoleAdmin(GOVERNOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(GUARDIAN_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(POLICY_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(VAULT_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(RESERVE_MANAGER_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(REWARD_MANAGER_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(RESERVE_DEPOSITOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(VAULT_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, GOVERNOR_ROLE);
    }

    modifier onlyGovernor() {
        require(hasRole(GOVERNOR_ROLE, msg.sender), "Only governor");
        _;
    }

    function setOperationsTreasury(address _newOperationsTreasury) external onlyGovernor {
        address oldOperationsTreasury = operationsTreasury;
        operationsTreasury = _newOperationsTreasury;
        emit OperationsTreasuryUpdated(_newOperationsTreasury, oldOperationsTreasury);
    }

    function setTreasury(address _newTreasury) external onlyGovernor {
        address oldTreasury = address(treasury);
        treasury = IDreTreasury(_newTreasury);
        emit TreasuryUpdated(_newTreasury, oldTreasury);
    }

    function addGovernor(address _newGovernor) external onlyGovernor {
        _grantRole(GOVERNOR_ROLE, _newGovernor);
    }

    function addGuardian(address _newGuardian) external onlyGovernor {
        _grantRole(GUARDIAN_ROLE, _newGuardian);
    }

    function addPolicy(address _newPolicy) external onlyGovernor {
        _grantRole(POLICY_ROLE, _newPolicy);
    }

    function addRewardManager(address _newRewardManager) external onlyGovernor {
        _grantRole(REWARD_MANAGER_ROLE, _newRewardManager);
    }

    function addReserveManager(address _newReserveManager) external onlyGovernor {
        _grantRole(RESERVE_MANAGER_ROLE, _newReserveManager);
    }

    function addReserveDepositor(address _newReserveDepositor) external onlyGovernor {
        _grantRole(RESERVE_DEPOSITOR_ROLE, _newReserveDepositor);
    }

    function addVault(address _newVault) external onlyGovernor {
        _grantRole(VAULT_ROLE, _newVault);
    }

    function addExecutor(address _newExecutor) external onlyGovernor {
        _grantRole(EXECUTOR_ROLE, _newExecutor);
    }

    function removeGovernor(address _oldGovernor) external onlyGovernor {
        _revokeRole(GOVERNOR_ROLE, _oldGovernor);
    }

    function removeGuardian(address _oldGuardian) external onlyGovernor {
        _revokeRole(GUARDIAN_ROLE, _oldGuardian);
    }

    function removePolicy(address _oldPolicy) external onlyGovernor {
        _revokeRole(POLICY_ROLE, _oldPolicy);
    }

    function removeRewardManager(address _oldRewardManager) external onlyGovernor {
        _revokeRole(REWARD_MANAGER_ROLE, _oldRewardManager);
    }

    function removeReserveManager(address _oldReserveManager) external onlyGovernor {
        _revokeRole(RESERVE_MANAGER_ROLE, _oldReserveManager);
    }

    function removeReserveDepositor(address _oldReserveDepositor) external onlyGovernor {
        _revokeRole(RESERVE_DEPOSITOR_ROLE, _oldReserveDepositor);
    }

    function removeVault(address _oldVault) external onlyGovernor {
        _revokeRole(VAULT_ROLE, _oldVault);
    }

    function removeExecutor(address _oldExecutor) external onlyGovernor {
        _revokeRole(EXECUTOR_ROLE, _oldExecutor);
    }

    function isGovernor(address account) external view override returns (bool) {
        return hasRole(GOVERNOR_ROLE, account);
    }

    function isRewardManager(address account) external view override returns (bool) {
        return hasRole(REWARD_MANAGER_ROLE, account);
    }

    function isReserveDepositor(address account) external view override returns (bool) {
        return hasRole(RESERVE_DEPOSITOR_ROLE, account);
    }

    function isReserveManager(address account) external view override returns (bool) {
        return hasRole(RESERVE_MANAGER_ROLE, account);
    }

    function isGuardian(address account) external view override returns (bool) {
        return hasRole(GUARDIAN_ROLE, account);
    }

    function isPolicy(address account) external view override returns (bool) {
        return hasRole(POLICY_ROLE, account);
    }

    function isVault(address account) external view override returns (bool) {
        return hasRole(VAULT_ROLE, account);
    }

    function isTreasury(address account) external view override returns (bool) {
        return account == address(treasury);
    }

    function isExecutor(address account) external view override returns (bool) {
        return hasRole(EXECUTOR_ROLE, account);
    }

    function getAllCandidates(bytes32 role) public view returns (address[] memory candidates) {
        uint256 count = getRoleMemberCount(role);
        candidates = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            candidates[i] = getRoleMember(role, i);
        }
    }

    function getAllReserveDepositorCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(RESERVE_DEPOSITOR_ROLE);
    }

    function getAllExecutorCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(EXECUTOR_ROLE);
    }

    function getAllPolicyCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(POLICY_ROLE);
    }

    function getAllVaultCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(VAULT_ROLE);
    }

    function getAllReserveManagerCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(RESERVE_MANAGER_ROLE);
    }

    function getAllRewardManagerCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(REWARD_MANAGER_ROLE);
    }

    function getAllGuardianCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(GUARDIAN_ROLE);
    }

    function getAllGovernorCandidates() external view returns (address[] memory candidates) {
        return getAllCandidates(GOVERNOR_ROLE);
    }
}
