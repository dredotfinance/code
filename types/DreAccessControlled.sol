// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.5;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "../interfaces/IDreAuthority.sol";

abstract contract DreAccessControlled is Initializable {
    event AuthorityUpdated(IDreAuthority indexed authority);

    string UNAUTHORIZED = "UNAUTHORIZED"; // save gas

    IDreAuthority public authority;

    function _initialize_DreAccessControlled(IDreAuthority _authority) internal {
        _setAuthority(_authority);
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

    modifier onlyRewardManager() {
        require(authority.isRewardManager(msg.sender), UNAUTHORIZED);
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

    modifier onlyVault() {
        require(authority.isVault(msg.sender), UNAUTHORIZED);
        _;
    }

    modifier onlyTreasury() {
        require(authority.isTreasury(msg.sender), UNAUTHORIZED);
        _;
    }

    /* ========== GOV ONLY ========== */

    function setAuthority(IDreAuthority _newAuthority) external onlyGovernor {
        _setAuthority(_newAuthority);
    }

    function _setAuthority(IDreAuthority _newAuthority) internal {
        authority = _newAuthority;
        emit AuthorityUpdated(_newAuthority);
    }
}
