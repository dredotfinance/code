// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "./AppAccessControlled.sol";
import "./interfaces/IApp.sol";
import "@layerzerolabs/oft-evm/contracts/OFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract RZR is OFT, ERC20Permit, Pausable, AppAccessControlled, IApp {
    constructor(address _lzEndpoint, address _authority)
        OFT("Rezerve.money", "RZR", _lzEndpoint, msg.sender)
        ERC20Permit("Rezerve")
        Ownable(msg.sender)
    {
        __AppAccessControlled_init(_authority);
        _transferOwnership(address(0));
        _mint(msg.sender, 1e18);
        _burn(msg.sender, 1e18);
    }

    function _checkOwner() internal view virtual override {
        if (!authority.isGovernor(_msgSender())) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
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
}
