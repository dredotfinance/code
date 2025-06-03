// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDRE.sol";
import "../interfaces/IDreStaking.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IDRE.sol";

interface IShadowRouter {
    struct route {
        /// @dev token from
        address from;
        /// @dev token to
        address to;
        /// @dev is stable route
        bool stable;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract BootstrapLP is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IDRE public immutable dreToken;
    IERC20 public immutable usdcToken;
    IERC20 public immutable lpToken;

    IDreStaking public immutable staking;
    IShadowRouter public immutable router;
    ITreasury public immutable treasury;

    uint256 public maxUsdcCapacity;
    uint256 public bonus;
    uint256 public usdcAquired;

    constructor(
        address _dreToken,
        address _usdcToken,
        address _lpToken,
        address _staking,
        address _router,
        address _treasury,
        uint256 _maxUsdcCapacity,
        uint256 _bonus
    ) Ownable(msg.sender) {
        dreToken = IDRE(_dreToken);
        usdcToken = IERC20(_usdcToken);
        lpToken = IERC20(_lpToken);
        staking = IDreStaking(_staking);
        router = IShadowRouter(_router);
        treasury = ITreasury(_treasury);
        maxUsdcCapacity = _maxUsdcCapacity;
        bonus = _bonus;

        dreToken.approve(address(router), type(uint256).max);
        usdcToken.approve(address(router), type(uint256).max);
        dreToken.approve(address(staking), type(uint256).max);
    }

    function setMaxUsdcCapacity(uint256 _maxUsdcCapacity) external onlyOwner {
        maxUsdcCapacity = _maxUsdcCapacity;
    }

    function setBonus(uint256 _bonus) external onlyOwner {
        bonus = _bonus;
    }

    function bootstrap(uint256 usdcAmount) external nonReentrant {
        require(usdcAmount > 0, "Amount must be greater than 0");
        uint256 totalReservesBefore = treasury.calculateReserves();

        // Transfer USDC from user
        usdcToken.safeTransferFrom(msg.sender, address(this), usdcAmount);
        usdcAquired += usdcAmount;
        require(usdcAquired <= maxUsdcCapacity, "Max USDC capacity reached");

        // Calculate DRE amount to mint (1:1 ratio)
        uint256 dreAmount = treasury.tokenValueE18(address(usdcToken), usdcAmount);

        // Mint DRE tokens with the half the USDC
        dreToken.mint(address(this), dreAmount / 2);
        usdcToken.safeTransfer(address(treasury), usdcAmount / 2);

        // Deposit into LP
        (,, uint256 lpReceived) = router.addLiquidity(
            address(dreToken),
            address(usdcToken),
            false,
            dreAmount / 2,
            usdcAmount / 2,
            0,
            0,
            address(this),
            block.timestamp
        );

        // Deposit the LP into the treasury
        uint256 dreAmountOfLp = treasury.tokenValueE18(address(lpToken), lpReceived) * bonus / 1e18;
        lpToken.safeTransfer(address(treasury), lpReceived);
        dreToken.mint(address(this), dreAmountOfLp);

        // require(dreAmountOfLp == dreAmount, "DRE amount of LP does not match DRE amount");

        // Stake into staking contract
        staking.createPosition(msg.sender, dreAmountOfLp, dreAmountOfLp, 0);
        // staking.createPosition(msg.sender, dreAmount, dreAmount, 0);

        // Burn any pending DRE
        if (dreToken.balanceOf(address(this)) > 0) {
            dreToken.burn(dreToken.balanceOf(address(this)));
        }

        // Return back any pending USDC
        if (usdcToken.balanceOf(address(this)) > 0) {
            usdcToken.safeTransfer(msg.sender, usdcToken.balanceOf(address(this)));
        }

        // invariant check - dont' mint DRE if we don't have enough reserves
        uint256 totalReservesAfter = treasury.calculateReserves();
        require(totalReservesAfter > totalReservesBefore, "Reserves invariant violated");
        require(totalReservesAfter >= dreToken.totalSupply(), "Reserves invariant violated");
    }

    // Emergency functions
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
    }

    function rescueETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}
