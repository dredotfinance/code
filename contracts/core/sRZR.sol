// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./AppAccessControlled.sol";

contract sRZR is ERC20Permit, AppAccessControlled {
    /// @notice Event emitted when the staking contract is updated
    /// @param stakingContract The new staking contract
    event StakingContractUpdated(address stakingContract);

    /// @notice Modifier to check if the caller is the staking contract
    /// @dev This modifier is only callable by the staking contract
    modifier onlyStakingContract() {
        require(msg.sender == stakingContract, "StakingContract:  call is not staking contract");
        _;
    }

    /// @notice The staking contract
    address public stakingContract;

    /// @notice Constructor
    /// @dev This function is only callable once
    /// @param _authority The address of the authority contract
    constructor(address _authority) ERC20("Staked RZR", "sRZR") ERC20Permit("Staked RZR") {
        __AppAccessControlled_init(_authority);
    }

    /// @notice Set the staking contract
    /// @dev This function is only callable by the governor
    /// @param _stakingContract The address of the staking contract
    function setStakingContract(address _stakingContract) external onlyGovernor {
        stakingContract = _stakingContract;
        emit StakingContractUpdated(_stakingContract);
    }

    /// @notice Mint function is only callable by the staking contract
    /// @dev This function is only callable by the staking contract
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external onlyStakingContract {
        _mint(to, amount);
    }

    /// @notice Burn function is not allowed
    /// @dev This function is not allowed
    /// @param from The address of the sender
    /// @param amount The amount of tokens to burn
    function burn(address from, uint256 amount) external onlyStakingContract {
        _burn(from, amount);
    }

    /// @notice Transfer function is not allowed
    /// @dev This function is not allowed
    /// @param to The address of the recipient
    /// @param value The amount of tokens to transfer
    /// @return bool True if the transfer is successful, false otherwise
    function transfer(address to, uint256 value) public override returns (bool) {
        require(false, "transfer not allowed");
        return super.transfer(to, value);
    }

    /// @notice Transfer function is not allowed
    /// @dev This function is not allowed
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param value The amount of tokens to transfer
    /// @return bool True if the transfer is successful, false otherwise
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        require(false, "transferFrom not allowed");
        return super.transferFrom(from, to, value);
    }
}
