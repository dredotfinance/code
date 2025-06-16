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
        uint256 usdcAquired = quoteToken.balanceOf(address(this));
        require(usdcAquired > 0, "Amount must be greater than 0");
        uint256 totalReservesBefore = treasury.calculateReserves();

        // Calculate RZR amount to mint (1:1 ratio)
        uint256 amountToMint = treasury.tokenValueE18(address(quoteToken), usdcAquired);

        // Mint RZR tokens with the half the USDC
        appToken.mint(address(this), amountToMint);
        quoteToken.transfer(address(treasury), usdcAquired / 2);

        // Deposit into LP
        (,, uint256 lpReceived) = router.addLiquidity(
            address(quoteToken),
            address(appToken),
            false,
            usdcAquired / 2,
            amountToMint,
            0,
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
        require(totalReservesAfter >= appToken.totalSupply(), "Reserves invariant violated");
    }

    // Emergency functions
    function rescueTokens(address token, uint256 amount) external onlyExecutor {
        IERC20(token).transfer(msg.sender, amount);
    }

    function rescueETH() external onlyExecutor {
        payable(msg.sender).transfer(address(this).balance);
    }
}
