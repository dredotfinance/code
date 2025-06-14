// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import {
    AccessControl,
    AccessControlEnumerable
} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract AppTimelock is AccessControlEnumerable, TimelockController {
    constructor(uint256 minDelay, address admin, address[] memory proposers)
        TimelockController(minDelay, proposers, proposers, admin)
    {}

    function _grantRole(bytes32 role, address account)
        internal
        virtual
        override(AccessControlEnumerable, AccessControl)
        returns (bool)
    {
        return super._grantRole(role, account);
    }

    function _revokeRole(bytes32 role, address account)
        internal
        override(AccessControlEnumerable, AccessControl)
        returns (bool)
    {
        return super._revokeRole(role, account);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlEnumerable, TimelockController)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getAllCandidates(bytes32 role) public view returns (address[] memory candidates) {
        uint256 count = getRoleMemberCount(role);
        candidates = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            candidates[i] = getRoleMember(role, i);
        }
    }

    function getAllProposers() public view returns (address[] memory proposers) {
        return getAllCandidates(PROPOSER_ROLE);
    }

    function getAllExecutors() public view returns (address[] memory executors) {
        return getAllCandidates(EXECUTOR_ROLE);
    }

    function getAllAdmins() public view returns (address[] memory admins) {
        return getAllCandidates(DEFAULT_ADMIN_ROLE);
    }

    function getAllCancellers() public view returns (address[] memory cancelers) {
        return getAllCandidates(CANCELLER_ROLE);
    }
}
