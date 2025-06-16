// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IShadowRouter.sol";

interface IBootstrapLP {
    // IERC20 public immutable usdcToken;
    function usdcToken() external view returns (IERC20);
    function bootstrap(uint256 tokenAmountIn, address to) external returns (uint256 dreAmountOfLp);
}
