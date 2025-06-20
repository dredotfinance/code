// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    uint8 public decimals_ = 18;

    function setDecimals(uint8 _decimals) public virtual {
        decimals_ = _decimals;
    }

    function decimals() public view override returns (uint8) {
        return decimals_;
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}
