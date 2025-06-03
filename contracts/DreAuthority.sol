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
}
