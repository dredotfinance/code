// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "./AppUIHelperBase.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title RZR UI Helper
/// @author RZR Protocol
contract AppUIHelperWrite is AppUIHelperBase {
    using SafeERC20 for IERC20;

    constructor(
        address _staking,
        address _bondDepository,
        address _treasury,
        address _dreToken,
        address _stakingToken,
        address _rebaseController,
        address _appOracle,
        address _shadowLP,
        address _bootstrapLP,
        address _odos
    )
        AppUIHelperBase(
            _staking,
            _bondDepository,
            _treasury,
            _dreToken,
            _stakingToken,
            _rebaseController,
            _appOracle,
            _shadowLP,
            _bootstrapLP,
            _odos
        )
    {}

    /// @notice Claim all rewards for a staking position
    /// @return amount The amount of rewards claimed
    function claimAllRewards(address user) external returns (uint256 amount) {
        uint256 balance = staking.balanceOf(user);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = staking.tokenOfOwnerByIndex(user, i);
            if (tokenId == 0) continue;
            // IAppStaking.Position memory position = staking.positions(tokenId);
            // if (position.cooldownEnd > block.timestamp) continue;
            amount += staking.claimRewards(tokenId);
        }
    }

    function zapAndMint(address to, uint256 tokenAmountIn, address tokenIn, bytes memory odosData)
        external
        payable
        returns (uint256 dreAmountOfLp)
    {
        if (tokenIn == address(0)) {
            require(msg.value == tokenAmountIn, "Invalid ETH amount");
        } else {
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenAmountIn);
        }

        if (tokenIn != address(0)) {
            IERC20(tokenIn).approve(odos, type(uint256).max);
        }

        (bool success,) = odos.call{value: tokenAmountIn}(odosData);
        require(success, "Odos call failed");

        IERC20 usdcToken = bootstrapLP.usdcToken();
        usdcToken.approve(address(bootstrapLP), type(uint256).max);
        uint256 balance = usdcToken.balanceOf(address(this));
        dreAmountOfLp = bootstrapLP.bootstrap(balance, to);

        _purge(address(usdcToken));
        _purge(address(appToken));
        _purge(address(tokenIn));
    }

    function zapAndStake(
        address to,
        uint256 tokenAmountIn,
        uint256 dreAmountDeclared,
        address tokenIn,
        bytes memory odosData
    ) external payable returns (uint256 dreAmountSwapped) {
        if (tokenIn == address(0)) {
            require(msg.value == tokenAmountIn, "Invalid ETH amount");
        } else {
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenAmountIn);
        }

        if (tokenIn != address(0)) {
            IERC20(tokenIn).approve(odos, type(uint256).max);
        }

        if (odosData.length > 0) {
            (bool success,) = odos.call{value: msg.value}(odosData);
            require(success, "Odos call failed");
        }

        dreAmountSwapped = appToken.balanceOf(address(this));
        staking.createPosition(to, dreAmountSwapped, dreAmountDeclared, 0);

        _purge(tokenIn);
        _purge(address(appToken));
    }

    function zapAndStakeAsPercentage(
        address to,
        uint256 tokenAmountIn,
        uint256 dreAmountDeclaredAsPercentage,
        address tokenIn,
        bytes memory odosData
    ) external payable returns (uint256 dreAmountSwapped) {
        if (tokenIn == address(0)) {
            require(msg.value == tokenAmountIn, "Invalid ETH amount");
        } else {
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenAmountIn);
        }

        if (tokenIn != address(0)) {
            IERC20(tokenIn).approve(odos, type(uint256).max);
        }

        if (odosData.length > 0) {
            (bool success,) = odos.call{value: msg.value}(odosData);
            require(success, "Odos call failed");
        }

        dreAmountSwapped = appToken.balanceOf(address(this));
        uint256 dreAmountDeclared = (dreAmountSwapped * dreAmountDeclaredAsPercentage) / 1e18;
        staking.createPosition(to, dreAmountSwapped, dreAmountDeclared, 0);

        _purge(tokenIn);
    }

    function _purge(address token) internal {
        if (token == address(0)) {
            (bool success,) = address(this).call{value: address(this).balance}("");
            require(success, "Failed to send ETH");
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                IERC20(token).safeTransfer(address(this), balance);
            }
        }
    }

    receive() external payable {}
}
