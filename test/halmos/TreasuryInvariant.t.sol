// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";

/// @notice This is a buggy token contract. DO NOT use it in production.
contract Token {
    mapping(address => uint256) public balanceOf;

    constructor() public {
        balanceOf[msg.sender] = 1e27;
    }

    function transfer(address to, uint256 amount) public {
        _transfer(msg.sender, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) public {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

contract TreasuryInvariantTest is Test, SymTest {
    Token token;

    function setUp() public {
        token = new Token();

        // set the balances of three arbitrary accounts to arbitrary symbolic values
        for (uint256 i = 0; i < 3; i++) {
            address receiver = svm.createAddress("receiver"); // create a new symbolic address
            uint256 amount = svm.createUint256("amount"); // create a new symbolic uint256 value
            token.transfer(receiver, amount);
        }
    }

    function checkBalanceUpdate() public {
        // consider two arbitrary distinct accounts
        address caller = svm.createAddress("caller"); // create a symbolic address
        address others = svm.createAddress("others"); // create another symbolic address
        vm.assume(others != caller); // assume the two addresses are different

        // record their current balances
        uint256 oldBalanceCaller = token.balanceOf(caller);
        uint256 oldBalanceOthers = token.balanceOf(others);

        // execute an arbitrary function call to the token from the caller
        vm.prank(caller);
        uint256 dataSize = 100; // the max calldata size for the public functions in the token
        bytes memory data = svm.createBytes(dataSize, "data"); // create a symbolic calldata
        address(token).call(data);

        // ensure that the caller cannot spend others' tokens
        assert(token.balanceOf(caller) <= oldBalanceCaller); // cannot increase their own balance
        assert(token.balanceOf(others) >= oldBalanceOthers); // cannot decrease others' balance
    }
}
