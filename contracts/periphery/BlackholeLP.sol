// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IApp.sol";
import "../interfaces/IAppTreasury.sol";
import "../interfaces/IBootstrapLP.sol";
import "../core/AppAccessControlled.sol";

contract BlackholeLP is AppAccessControlled {
    IApp public appToken;
    IERC20 public quoteToken;
    IERC20 public lpToken;
    IShadowRouter public router;
    IAppTreasury public treasury;

    constructor(
        address _appToken,
        address _quoteToken,
        address _lpToken,
        address _router,
        address _treasury,
        address _authority
    ) {
        appToken = IApp(_appToken);
        quoteToken = IERC20(_quoteToken);
        lpToken = IERC20(_lpToken);
        router = IShadowRouter(_router);
        treasury = IAppTreasury(_treasury);

        _setAuthority(IAppAuthority(_authority));

        appToken.approve(address(router), type(uint256).max);
        quoteToken.approve(address(router), type(uint256).max);
    }

    function purge() external onlyExecutor {
        uint256 acquired = quoteToken.balanceOf(address(this));
        require(acquired > 0, "Amount must be greater than 0");
        uint256 totalReservesBefore = treasury.calculateReserves();

        // Calculate RZR amount to mint (1:1 ratio)
        uint256 amountToMint = treasury.tokenValueE18(address(quoteToken), acquired);

        // Mint RZR tokens with the half the USDC
        appToken.mint(address(this), amountToMint);

        // Deposit into LP
        (,, uint256 lpReceived) = router.addLiquidity(
            address(quoteToken),
            address(appToken),
            false,
            acquired,
            amountToMint,
            acquired,
            0,
            address(this),
            block.timestamp
        );

        // Deposit the LP into the treasury
        lpToken.transfer(address(treasury), lpReceived);
        treasury.syncReserves();

        // Burn any pending RZR
        if (appToken.balanceOf(address(this)) > 0) {
            appToken.burn(appToken.balanceOf(address(this)));
        }

        // invariant check - dont' mint RZR if we don't have enough reserves
        uint256 totalReservesAfter = treasury.calculateReserves();
        require(totalReservesAfter > totalReservesBefore, "Reserves invariant violated");
        require(totalReservesAfter >= treasury.totalSupply(), "Reserves invariant violated");
    }

    function swap(address tokenIn, bool stable, uint256 minAmountOut) external {
        uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));
        IERC20(tokenIn).approve(address(router), type(uint256).max);

        IShadowRouter.route[] memory routes = new IShadowRouter.route[](1);
        routes[0] = IShadowRouter.route({from: tokenIn, to: address(quoteToken), stable: stable});
        router.swapExactTokensForTokens(amountIn, minAmountOut, routes, address(this), block.timestamp);
    }

    function rescueTokens(address token, uint256 amount) external onlyExecutor {
        IERC20(token).transfer(msg.sender, amount);
    }

    function rescueETH() external onlyExecutor {
        payable(msg.sender).transfer(address(this).balance);
    }
}
