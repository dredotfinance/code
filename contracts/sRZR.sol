// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./AppAccessControlled.sol";

contract sRZR is ERC20Permit, AppAccessControlled {
    event StakingContractUpdated(address stakingContract);

    modifier onlyStakingContract() {
        require(msg.sender == stakingContract, "StakingContract:  call is not staking contract");
        _;
    }

    address public stakingContract;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _authority) ERC20("Staked RZR", "sRZR") ERC20Permit("Staked RZR") {
        __AppAccessControlled_init(_authority);
    }

    /* ========== INITIALIZATION ========== */

    function setStakingContract(address _stakingContract) external onlyGovernor {
        stakingContract = _stakingContract;
        emit StakingContractUpdated(_stakingContract);
    }

    function mint(address to, uint256 amount) external onlyStakingContract {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyStakingContract {
        _burn(from, amount);
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        require(false, "transfer not allowed");
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        require(false, "transferFrom not allowed");
        return super.transferFrom(from, to, value);
    }
}
