// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IAppAuthority.sol";

interface ISonicFeeMRegistry {
    function selfRegister(uint256 projectID) external;
}

/// @title AppAccessControlled
/// @notice This contract is used to control access to the App contract
abstract contract AppAccessControlled is Initializable {
    /// @notice Event emitted when the authority is updated
    /// @param authority The new authority
    event AuthorityUpdated(IAppAuthority indexed authority);

    /// @notice The authority contract
    IAppAuthority public authority;

    /// @notice Initializes the AppAccessControlled contract
    /// @dev This function is only callable once
    /// @param _authority The address of the authority contract
    function __AppAccessControlled_init(address _authority) internal {
        _setAuthority(IAppAuthority(_authority));
    }

    /// @notice Modifier to check if the caller is a governor
    /// @dev This modifier is only callable by the governor
    modifier onlyGovernor() {
        require(authority.isGovernor(msg.sender), "UNAUTHORIZED");
        _;
    }

    /// @notice Modifier to check if the caller is a guardian or governor
    /// @dev This modifier is only callable by the guardian or governor
    modifier onlyGuardianOrGovernor() {
        require(authority.isGuardian(msg.sender) || authority.isGovernor(msg.sender), "UNAUTHORIZED");
        _;
    }

    /// @notice Modifier to check if the caller is a reserve manager
    /// @dev This modifier is only callable by the reserve manager
    modifier onlyReserveManager() {
        require(authority.isReserveManager(msg.sender), "UNAUTHORIZED");
        _;
    }

    /// @notice Modifier to check if the caller is a reserve depositor
    /// @dev This modifier is only callable by the reserve depositor
    modifier onlyReserveDepositor() {
        require(authority.isReserveDepositor(msg.sender), "UNAUTHORIZED");
        _;
    }

    /// @notice Modifier to check if the caller is a guardian
    /// @dev This modifier is only callable by the guardian
    modifier onlyGuardian() {
        require(authority.isGuardian(msg.sender), "UNAUTHORIZED");
        _;
    }

    /// @notice Modifier to check if the caller is a policy
    /// @dev This modifier is only callable by the policy
    modifier onlyPolicy() {
        require(authority.isPolicy(msg.sender), "UNAUTHORIZED");
        _;
    }

    /// @notice Modifier to check if the caller is the treasury
    /// @dev This modifier is only callable by the treasury
    modifier onlyTreasury() {
        require(authority.isTreasury(msg.sender), "UNAUTHORIZED");
        _;
    }

    /// @notice Modifier to check if the caller is an executor
    /// @dev This modifier is only callable by the executor
    modifier onlyExecutor() {
        require(authority.isExecutor(msg.sender), "UNAUTHORIZED");
        _;
    }

    /// @notice Modifier to check if the caller is a bond manager
    /// @dev This modifier is only callable by the bond manager
    modifier onlyBondManager() {
        require(authority.isBondManager(msg.sender), "UNAUTHORIZED");
        _;
    }

    /// @notice Sets the authority for the contract
    /// @dev This function is only callable by the governor
    /// @param _newAuthority The address of the new authority
    function setAuthority(IAppAuthority _newAuthority) external onlyGovernor {
        _setAuthority(_newAuthority);
    }

    /// @notice Sets the authority for the contract
    /// @dev This function is only callable by the governor
    /// @param _newAuthority The address of the new authority
    function _setAuthority(IAppAuthority _newAuthority) internal {
        authority = _newAuthority;
        emit AuthorityUpdated(_newAuthority);
    }

    /// @notice Sets the project ID for the fee registry
    /// @dev This function is only callable by the governor
    /// @param registry The address of the fee registry
    /// @param projectID The project ID to set
    function setFeeMProjectId(address registry, uint256 projectID) external onlyGovernor {
        ISonicFeeMRegistry(registry).selfRegister(projectID);
    }
}
