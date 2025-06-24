// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "./AppUIHelperBase.sol";
import "../interfaces/IAppReferrals.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title RZR UI Helper
/// @author RZR Protocol
contract AppUIHelperWrite is AppUIHelperBase {
    using SafeERC20 for IERC20;

    IAppReferrals public referrals;

    struct OdosParams {
        address tokenIn;
        uint256 tokenAmountIn;
        address odosTokenIn;
        uint256 odosTokenAmountIn;
        bytes odosData;
    }

    struct BondParams {
        uint256 id;
        uint256 amount;
        uint256 maxPrice;
        uint256 minPayout;
        bytes8 referralCode;
    }

    struct StakeParams {
        uint256 amountDeclared;
        uint256 amountDeclaredAsPercentage;
        bytes8 referralCode;
    }

    constructor(
        address _staking,
        address _bondDepository,
        address _treasury,
        address _appToken,
        address _stakingToken,
        address _rebaseController,
        address _appOracle,
        address _shadowLP,
        address _odos,
        address _referrals
    )
        AppUIHelperBase(
            _staking,
            _bondDepository,
            _treasury,
            _appToken,
            _stakingToken,
            _rebaseController,
            _appOracle,
            _shadowLP,
            _odos
        )
    {
        referrals = IAppReferrals(_referrals);
    }

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

    /// @notice Zaps and buys a bond
    /// @param odosParams The parameters for the zap
    /// @param bondParams The parameters for the bond
    /// @return payout_ The amount of RZR tokens received
    /// @return tokenId_ The ID of the created bond position NFT
    function zapAndBuyBond(OdosParams memory odosParams, BondParams memory bondParams)
        external
        payable
        returns (uint256 payout_, uint256 tokenId_)
    {
        _prepareZap(odosParams);
        IERC20(odosParams.odosTokenIn).approve(address(referrals), type(uint256).max);
        (payout_, tokenId_) = referrals.bondWithReferral(
            bondParams.id,
            IERC20(odosParams.odosTokenIn).balanceOf(address(this)),
            bondParams.maxPrice,
            bondParams.minPayout,
            bondParams.referralCode,
            msg.sender
        );
        _purgeAll(odosParams);
    }

    /// @notice Zaps and stakes the given token amount
    /// @param odosParams The parameters for the zap
    /// @param stakeParams The parameters for the stake
    /// @return tokenId The ID of the created stake position NFT
    /// @return taxPaid The amount of tax paid
    /// @return amountStaked The amount of app tokens staked
    /// @return amountDeclared The amount of app tokens declared
    function zapAndStake(OdosParams memory odosParams, StakeParams memory stakeParams)
        external
        payable
        returns (uint256 tokenId, uint256 taxPaid, uint256 amountStaked, uint256 amountDeclared)
    {
        _prepareZap(odosParams);

        amountStaked = appToken.balanceOf(address(this));
        appToken.approve(address(referrals), amountStaked);
        amountDeclared = stakeParams.amountDeclared;
        (tokenId, taxPaid) =
            referrals.stakeWithReferral(amountStaked, amountDeclared, stakeParams.referralCode, msg.sender);

        _purgeAll(odosParams);
    }

    /// @notice Zaps and stakes the given token amount as a percentage of the app token balance
    /// @param odosParams The parameters for the zap
    /// @param stakeParams The parameters for the stake
    /// @return tokenId The ID of the created stake position NFT
    /// @return taxPaid The amount of tax paid
    /// @return amountStaked The amount of app tokens staked
    /// @return amountDeclared The amount of app tokens declared
    function zapAndStakeAsPercentage(OdosParams memory odosParams, StakeParams memory stakeParams)
        external
        payable
        returns (uint256 tokenId, uint256 taxPaid, uint256 amountStaked, uint256 amountDeclared)
    {
        _prepareZap(odosParams);

        amountStaked = appToken.balanceOf(address(this));
        amountDeclared = (amountStaked * stakeParams.amountDeclaredAsPercentage) / 1e18;
        appToken.approve(address(referrals), amountStaked);
        (tokenId, taxPaid) =
            referrals.stakeWithReferral(amountStaked, amountDeclared, stakeParams.referralCode, msg.sender);

        _purgeAll(odosParams);
    }

    /// @notice Purges all tokens from the contract
    /// @param odosParams The parameters for the zap
    function _purgeAll(OdosParams memory odosParams) internal {
        _purge(odosParams.tokenIn);
        _purge(odosParams.odosTokenIn);
        _purge(address(appToken));
    }

    /// @notice Purges the given token
    /// @param token The token to purge
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

    /// @notice Prepares the zap for the given token and odos data
    /// @param odosParams The parameters for the zap
    function _prepareZap(OdosParams memory odosParams) internal {
        if (odosParams.tokenIn == address(0)) {
            require(msg.value == odosParams.tokenAmountIn, "Invalid ETH amount");
        } else {
            IERC20(odosParams.tokenIn).safeTransferFrom(msg.sender, address(this), odosParams.tokenAmountIn);
        }

        if (odosParams.tokenIn != address(0)) {
            IERC20(odosParams.tokenIn).approve(odos, type(uint256).max);
        }

        if (odosParams.odosData.length > 0) {
            (bool success,) = odos.call{value: msg.value}(odosParams.odosData);
            require(success, "Odos call failed");
        }
    }

    receive() external payable {}
}
