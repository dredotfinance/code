// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "./AppUIHelperBase.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title RZR UI Helper
/// @author RZR Protocol
contract AppUIHelperRead is AppUIHelperBase {
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

    /// @notice Get all protocol information for a user
    /// @param user The address of the user
    function getProtocolInfo(address user, address[] memory bondTokens)
        external
        view
        returns (
            uint256 tvl,
            uint256 totalSupply,
            uint256 totalStaked,
            uint256 totalRewards,
            uint256 currentAPR,
            uint256 currentSpotPrice,
            TokenInfo[] memory tokenInfos,
            StakingPositionInfo[] memory stakingPositions,
            BondPositionInfo[] memory bondPositions,
            ProjectedEpochRate memory projectedEpochRate
        )
    {
        // Get protocol-wide stats
        tvl = treasury.calculateReserves();
        totalSupply = appToken.totalSupply();
        totalStaked = staking.totalStaked();
        totalRewards = staking.rewardPerToken();
        currentAPR = calculateAPRRaw(totalStaked);
        currentSpotPrice = shadowLP.getPrice();
        projectedEpochRate = getProjectedEpochRate();
        tokenInfos = getTokenInfos(user, bondTokens);
        stakingPositions = getStakingPositions(user);
        bondPositions = getBondPositions(user);
    }

    function getTokenInfos(address user, address[] memory bondTokens)
        internal
        view
        returns (TokenInfo[] memory tokenInfos)
    {
        tokenInfos = new TokenInfo[](bondTokens.length + 2); // +1 for RZR token, +1 for staking token

        // Add RZR token info
        tokenInfos[0] = TokenInfo({
            token: address(appToken),
            name: "RZR",
            symbol: "RZR",
            balance: appToken.balanceOf(user),
            allowance: appToken.allowance(user, address(staking)),
            treasuryBalance: appToken.balanceOf(address(treasury)),
            treasuryValueApp: appToken.balanceOf(address(treasury)),
            decimals: 18,
            oraclePrice: appOracle.getTokenPrice(),
            oraclePriceInApp: 1e18
        });

        // Add staking token info
        tokenInfos[1] = TokenInfo({
            token: address(stakingToken),
            name: "Staked RZR",
            symbol: "sRZR",
            balance: stakingToken.balanceOf(user),
            allowance: stakingToken.allowance(user, address(staking)),
            treasuryBalance: 0,
            treasuryValueApp: 0,
            decimals: 18,
            oraclePrice: 0,
            oraclePriceInApp: 0
        });

        // Add bond token info
        for (uint256 i = 0; i < bondTokens.length; i++) {
            IERC20Metadata token = IERC20Metadata(bondTokens[i]);
            tokenInfos[i + 2] = TokenInfo({
                balance: token.balanceOf(user),
                allowance: token.allowance(user, address(bondDepository)),
                decimals: token.decimals(),
                name: token.name(),
                symbol: token.symbol(),
                treasuryBalance: token.balanceOf(address(treasury)),
                treasuryValueApp: treasury.tokenValueE18(address(token), token.balanceOf(address(treasury))),
                token: address(token),
                oraclePriceInApp: appOracle.getPriceInToken(address(token)),
                oraclePrice: appOracle.getPrice(address(token))
            });
        }
    }

    function getStakingPositions(address user) internal view returns (StakingPositionInfo[] memory stakingPositions) {
        uint256 stakingBalance = staking.balanceOf(user);
        stakingPositions = new StakingPositionInfo[](stakingBalance);

        for (uint256 i = 0; i < stakingBalance; i++) {
            uint256 tokenId = staking.tokenOfOwnerByIndex(user, i);
            if (tokenId == 0) continue;
            IAppStaking.Position memory position = staking.positions(tokenId);

            stakingPositions[i] = StakingPositionInfo({
                owner: user,
                id: tokenId,
                amount: position.amount,
                declaredValue: position.declaredValue,
                rewards: staking.earned(tokenId),
                cooldownEnd: position.cooldownEnd,
                rewardsUnlockAt: position.rewardsUnlockAt,
                isActive: position.cooldownEnd == 0
            });
        }
    }

    function getBondPositions(address user) internal view returns (BondPositionInfo[] memory bondPositions) {
        uint256 bondBalance = bondDepository.balanceOf(user);
        bondPositions = new BondPositionInfo[](bondBalance);

        for (uint256 i = 0; i < bondBalance; i++) {
            uint256 tokenId = bondDepository.tokenOfOwnerByIndex(user, i);
            IAppBondDepository.BondPosition memory position = bondDepository.positions(tokenId);

            bondPositions[i] = BondPositionInfo({
                id: tokenId,
                bondId: position.bondId,
                amount: position.amount,
                quoteAmount: position.quoteAmount,
                startTime: position.startTime,
                lastClaimTime: position.lastClaimTime,
                claimedAmount: position.claimedAmount,
                claimableAmount: bondDepository.claimableAmount(tokenId),
                isStaked: position.isStaked
            });
        }
    }

    function getProjectedEpochRate() internal view returns (ProjectedEpochRate memory projectedEpochRate) {
        (uint256 apr, uint256 epochRate, uint256 toStakers, uint256 toOps, uint256 toBurner) =
            rebaseController.projectedEpochRate();
        projectedEpochRate =
            ProjectedEpochRate({apr: apr, epochRate: epochRate, toStakers: toStakers, toOps: toOps, toBurner: toBurner});
    }

    /// @notice Calculate the current APR
    /// @return The current APR as a percentage (e.g., 1000 = 10%)
    function calculateAPR() public view returns (uint256) {
        return calculateAPRRaw(staking.totalStaked());
    }

    function calculateAPRRaw(uint256 totalStaked) public view returns (uint256) {
        (,, uint256 toStakers,,) = rebaseController.projectedEpochRate();
        return toStakers * 1e18 * 365 * 4 / totalStaked;
    }

    function getAllStakingPositions(uint256 startingIndex, uint256 endingIndex)
        external
        view
        returns (StakingPositionInfo[] memory)
    {
        StakingPositionInfo[] memory positions = new StakingPositionInfo[](endingIndex - startingIndex);

        for (uint256 i = startingIndex; i < endingIndex; i++) {
            IAppStaking.Position memory position = staking.positions(i);

            positions[i - startingIndex] = StakingPositionInfo({
                id: i,
                owner: staking.ownerOf(i),
                amount: position.amount,
                declaredValue: position.declaredValue,
                rewards: staking.earned(i),
                cooldownEnd: position.cooldownEnd,
                rewardsUnlockAt: position.rewardsUnlockAt,
                isActive: position.cooldownEnd == 0
            });
        }

        return positions;
    }

    function getBondVariables(uint256[] memory bondIds)
        external
        view
        returns (IAppBondDepository.Bond[] memory bonds, uint256[] memory currentPrices)
    {
        bonds = new IAppBondDepository.Bond[](bondIds.length);
        currentPrices = new uint256[](bondIds.length);

        for (uint256 i = 0; i < bondIds.length; i++) {
            IAppBondDepository.Bond memory bond = bondDepository.bonds(bondIds[i]);
            bonds[i] = bond;
            currentPrices[i] = bondDepository.currentPrice(bondIds[i]);
        }
    }
}
