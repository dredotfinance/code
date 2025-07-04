// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.28;

import "../core/AppAccessControlled.sol";

contract AccessControlledMock is AppAccessControlled {
    constructor(address _auth) {
        _setAuthority(IAppAuthority(_auth));
    }

    bool public governorOnlyTest;

    bool public guardianOnlyTest;

    bool public policyOnlyTest;

    bool public vaultOnlyTest;

    function governorTest() external onlyGovernor returns (bool) {
        governorOnlyTest = true;
        return governorOnlyTest;
    }

    function guardianTest() external onlyGuardian returns (bool) {
        guardianOnlyTest = true;
        return guardianOnlyTest;
    }

    function policyTest() external onlyPolicy returns (bool) {
        policyOnlyTest = true;
        return policyOnlyTest;
    }
}
