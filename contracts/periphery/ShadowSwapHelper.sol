// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IShadowRouter.sol";

contract ShadowSwapHelper {
    IShadowRouter public immutable router;

    constructor(IShadowRouter _router) {
        router = _router;
    }

    function swap(
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        bool stable,
        address to,
        uint256 deadline
    ) external {
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        tokenIn.approve(address(router), amountIn);

        IShadowRouter.route[] memory routes = new IShadowRouter.route[](1);
        routes[0] = IShadowRouter.route({from: address(tokenIn), to: address(tokenOut), stable: stable});

        router.swapExactTokensForTokens(amountIn, amountOutMin, routes, to, deadline);
    }
}
