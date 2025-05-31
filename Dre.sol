// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.7.5;

import "./libraries/SafeMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IDRE.sol";
import "./interfaces/IERC20Permit.sol";
import "./types/ERC20Permit.sol";
import "./types/DreAccessControlled.sol";

contract DRE is ERC20Permit, IDRE, DreAccessControlled {
    using SafeMath for uint256;
    bool public paused;

    event Paused();
    event Unpaused();

    constructor(address _authority) ERC20("Dre.finance", "DRE", 18) ERC20Permit("DreFinance") {
        _setAuthority(IDreAuthority(_authority));
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    function pause() external onlyGuardian {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyGuardian {
        paused = false;
        emit Unpaused();
    }

    function mint(address account_, uint256 amount_) external override onlyTreasury whenNotPaused {
        _mint(account_, amount_);
    }

    function burn(uint256 amount) external override whenNotPaused {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account_, uint256 amount_) external override whenNotPaused {
        _burnFrom(account_, amount_);
    }

    function _burnFrom(address account_, uint256 amount_) internal {
        uint256 decreasedAllowance_ =
            allowance(account_, msg.sender).sub(amount_, "ERC20: burn amount exceeds allowance");

        _approve(account_, msg.sender, decreasedAllowance_);
        _burn(account_, amount_);
    }
}
