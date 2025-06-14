// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IOracle.sol";

contract MockOracle is IOracle {
    uint256 private _price;

    constructor(uint256 price_) {
        _price = price_;
    }

    function getPrice() external view override returns (uint256) {
        return _price;
    }

    function setPrice(uint256 price_) external {
        _price = price_;
    }
}
