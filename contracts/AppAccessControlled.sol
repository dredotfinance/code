// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IAppAuthority.sol";

interface ISonicFeeMRegistry {
    function selfRegister(uint256 projectID) external;
}

abstract contract AppAccessControlled is Initializable {
    event AuthorityUpdated(IAppAuthority indexed authority);

    string UNAUTHORIZED = "UNAUTHORIZED"; // save gas

    IAppAuthority public authority;

    function __AppAccessControlled_init(address _authority) internal {
        _setAuthority(IAppAuthority(_authority));
    }

    modifier onlyGovernor() {
        require(authority.isGovernor(msg.sender), UNAUTHORIZED);
        _;
    }

    modifier onlyGuardianOrGovernor() {
        require(authority.isGuardian(msg.sender) || authority.isGovernor(msg.sender), UNAUTHORIZED);
        _;
    }

    modifier onlyReserveManager() {
        require(authority.isReserveManager(msg.sender), UNAUTHORIZED);
        _;
    }

    modifier onlyReserveDepositor() {
        require(authority.isReserveDepositor(msg.sender), UNAUTHORIZED);
        _;
    }

    modifier onlyGuardian() {
        require(authority.isGuardian(msg.sender), UNAUTHORIZED);
        _;
    }

    modifier onlyPolicy() {
        require(authority.isPolicy(msg.sender), UNAUTHORIZED);
        _;
    }

    modifier onlyTreasury() {
        require(authority.isTreasury(msg.sender), UNAUTHORIZED);
        _;
    }

    modifier onlyExecutor() {
        require(authority.isExecutor(msg.sender), UNAUTHORIZED);
        _;
    }

    modifier onlyBondManager() {
        require(authority.isBondManager(msg.sender), UNAUTHORIZED);
        _;
    }

    /* ========== GOV ONLY ========== */

    function setAuthority(IAppAuthority _newAuthority) external onlyGovernor {
        _setAuthority(_newAuthority);
    }

    function _setAuthority(IAppAuthority _newAuthority) internal {
        authority = _newAuthority;
        emit AuthorityUpdated(_newAuthority);
    }

    function setFeeMProjectId(address registry, uint256 projectID) external onlyGovernor {
        ISonicFeeMRegistry(registry).selfRegister(projectID);
    }
}
