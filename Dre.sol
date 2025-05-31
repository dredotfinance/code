// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IDRE.sol";
import "./DreAccessControlled.sol";

contract DRE is ERC20Permit, Pausable, DreAccessControlled, IDRE {
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    constructor(
        address _authority
    ) ERC20("Dre.finance", "DRE") ERC20Permit("DreFinance") {
        __DreAccessControlled_init(_authority);
    }

    function pause() external onlyGuardian {
        _pause();
    }

    function unpause() external onlyGuardian {
        _unpause();
    }

    function mint(address account_, uint256 amount_) external override onlyPolicy whenNotPaused {
        _mint(account_, amount_);
    }

    function burn(uint256 amount) external override whenNotPaused {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account_, uint256 amount_) external override whenNotPaused {
        _spendAllowance(account_, msg.sender, amount_);
        _burn(account_, amount_);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}
