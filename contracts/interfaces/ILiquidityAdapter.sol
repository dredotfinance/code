// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ILiquidityAdapter {
    /// @notice The token A of the liquidity adapter
    /// @return The address of token A
    function tokenA() external view returns (address);

    /// @notice The token B of the liquidity adapter
    /// @return The address of token B
    function tokenB() external view returns (address);

    /// @notice Add liquidity to the liquidity adapter
    /// @param amountADesired The desired amount of token A
    /// @param amountBDesired The desired amount of token B
    /// @param amountAMin The minimum amount of token A to accept
    /// @param amountBMin The minimum amount of token B to accept
    /// @return amountA The actual amount of token A added
    /// @return amountB The actual amount of token B added
    function addLiquidity(uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin)
        external
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Quote the amount of token A and token B needed to add liquidity
    /// @param amountADesired The desired amount of token A
    /// @param amountBDesired The desired amount of token B
    /// @return amountA The amount of token A needed
    /// @return amountB The amount of token B needed
    function quoteAddLiquidity(uint256 amountADesired, uint256 amountBDesired)
        external
        view
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}
