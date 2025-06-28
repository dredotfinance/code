// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/ILiquidityAdapter.sol";
import "../../interfaces/IShadowRouter.sol";

contract ShadowAdapter is ILiquidityAdapter {
    using SafeERC20 for IERC20;

    IShadowRouter public immutable router;
    bool public immutable stable;

    /// @inheritdoc ILiquidityAdapter
    address public immutable tokenA;

    /// @inheritdoc ILiquidityAdapter
    address public immutable tokenB;

    constructor(IShadowRouter _router, address _tokenA, address _tokenB, bool _stable) {
        router = _router;
        tokenA = _tokenA;
        tokenB = _tokenB;
        stable = _stable;
    }

    /// @inheritdoc ILiquidityAdapter
    function addLiquidity(uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin)
        external
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        // Transfer tokens from user to this contract
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountBDesired);

        // Approve router to spend tokens
        IERC20(tokenA).approve(address(router), amountADesired);
        IERC20(tokenB).approve(address(router), amountBDesired);

        // Add liquidity through router
        (amountA, amountB, liquidity) = router.addLiquidity(
            tokenA, tokenB, stable, amountADesired, amountBDesired, amountAMin, amountBMin, msg.sender, block.timestamp
        );

        _purge(tokenA);
        _purge(tokenB);
    }

    function _purge(address token) internal {
        if (token == address(0)) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, "Failed to send ETH");
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                IERC20(token).safeTransfer(msg.sender, balance);
            }
        }
    }
}
