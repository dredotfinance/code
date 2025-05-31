// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.7.5;

import "./types/ERC20Permit.sol";
import "./types/DreAccessControlled.sol";

contract sDRE is ERC20Permit, DreAccessControlled {
  event StakingContractUpdated(address stakingContract);

  modifier onlyStakingContract() {
    require(msg.sender == stakingContract, "StakingContract:  call is not staking contract");
    _;
  }

  address public stakingContract;

  /* ========== CONSTRUCTOR ========== */

  constructor(IDreAuthority _authority) ERC20("Staked DRE", "sDRE", 18) ERC20Permit("Staked DRE") {}

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

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) public override returns (bool) {
    require(false, "transferFrom not allowed");
    return super.transferFrom(from, to, value);
  }
}
