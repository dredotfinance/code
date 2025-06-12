// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

interface IPermissionedERC20 {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
