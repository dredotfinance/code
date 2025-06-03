// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ManualOracle
 * @notice An oracle that allows the operator to set the price.
 * @dev This oracle is used to set the price of a token.
 * @dev The operator is the address that can set the price.
 * @dev The price is set in 1e18.
 */
contract ManualOracleE18 is IOracle, Ownable {
    int256 public price;
    address public operator;

    event PriceSet(int256 price);

    constructor(int256 _price, address _operator) Ownable(msg.sender) {
        price = _price;
        operator = _operator;
    }

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
    }

    function setPrice(int256 _price) external {
        require(_price > 0, "Invalid price");
        require(msg.sender == operator, "Not operator");
        price = _price;
        emit PriceSet(price);
    }

    function getPrice() external view returns (uint256) {
        return uint256(price);
    }
}
