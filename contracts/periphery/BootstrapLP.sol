// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IAppStaking.sol";
import "../interfaces/IAppTreasury.sol";
import "../interfaces/IApp.sol";
import "../interfaces/IBootstrapLP.sol";

contract BootstrapLP is IBootstrapLP, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IApp public immutable appToken;
    IERC20 public immutable usdcToken;
    IERC20 public immutable lpToken;

    IAppStaking public immutable staking;
    IShadowRouter public immutable router;
    IAppTreasury public immutable treasury;

    uint256 public maxUsdcCapacity;
    uint256 public bonus;
    uint256 public usdcAquired;

    constructor(
        address _appToken,
        address _usdcToken,
        address _lpToken,
        address _staking,
        address _router,
        address _treasury,
        uint256 _maxUsdcCapacity,
        uint256 _bonus,
        uint256 _filled
    ) Ownable(msg.sender) {
        appToken = IApp(_appToken);
        usdcToken = IERC20(_usdcToken);
        lpToken = IERC20(_lpToken);
        staking = IAppStaking(_staking);
        router = IShadowRouter(_router);
        treasury = IAppTreasury(_treasury);
        maxUsdcCapacity = _maxUsdcCapacity;
        bonus = _bonus;
        usdcAquired = _filled;

        appToken.approve(address(router), type(uint256).max);
        usdcToken.approve(address(router), type(uint256).max);
        appToken.approve(address(staking), type(uint256).max);
    }

    function setMaxUsdcCapacity(uint256 _maxUsdcCapacity) external onlyOwner {
        maxUsdcCapacity = _maxUsdcCapacity;
    }

    function setBonus(uint256 _bonus) external onlyOwner {
        bonus = _bonus;
    }

    function bootstrap(uint256 usdcAmount, address to) external nonReentrant returns (uint256 dreAmountOfLp) {
        require(usdcAmount > 0, "Amount must be greater than 0");
        uint256 totalReservesBefore = reserves();

        // Transfer USDC from user
        usdcToken.safeTransferFrom(msg.sender, address(this), usdcAmount);
        usdcAquired += usdcAmount;
        require(usdcAquired <= maxUsdcCapacity, "Max USDC capacity reached");

        // Calculate RZR amount to mint (1:1 ratio)
        uint256 dreAmountToMint = treasury.tokenValueE18(address(usdcToken), usdcAmount);

        // Mint RZR tokens with the half the USDC
        appToken.mint(address(this), dreAmountToMint / 2);
        usdcToken.safeTransfer(address(treasury), usdcAmount / 2);

        // Deposit into LP
        (,, uint256 lpReceived) = router.addLiquidity(
            address(usdcToken),
            address(appToken),
            false,
            usdcAmount / 2,
            dreAmountToMint / 2,
            0,
            0,
            address(this),
            block.timestamp
        );

        // Deposit the LP into the treasury
        dreAmountOfLp = treasury.tokenValueE18(address(lpToken), lpReceived) * bonus / 1e18;
        lpToken.safeTransfer(address(treasury), lpReceived);
        appToken.mint(address(this), dreAmountOfLp);

        // require(dreAmountOfLp == dreAmount, "RZR amount of LP does not match RZR amount");

        // Stake into staking contract
        staking.createPosition(to, dreAmountOfLp, dreAmountOfLp, 0);

        // Burn any pending RZR
        if (appToken.balanceOf(address(this)) > 0) {
            appToken.burn(appToken.balanceOf(address(this)));
        }

        // Return back any pending USDC
        if (usdcToken.balanceOf(address(this)) > 0) {
            usdcToken.safeTransfer(to, usdcToken.balanceOf(address(this)));
        }

        // invariant check - dont' mint RZR if we don't have enough reserves
        uint256 totalReservesAfter = reserves();
        require(totalReservesAfter > totalReservesBefore, "Reserves invariant violated");
        require(totalReservesAfter >= appToken.totalSupply(), "Reserves invariant violated");

        return dreAmountOfLp;
    }

    // Emergency functions
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
    }

    function rescueETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function reserves() public view returns (uint256) {
        return treasury.calculateReserves() + appToken.balanceOf(address(treasury));
    }
}
