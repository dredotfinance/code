// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.15;
pragma abicoder v2;

import "./interfaces/IDreStaking.sol";
import "./interfaces/IDreBondDepository.sol";
import "./interfaces/IRebaseController.sol";
import "./interfaces/IDreTreasury.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title DRE UI Helper
/// @author DRE Protocol
contract DreUIHelper {
    // Structs
    struct TokenInfo {
        address token;
        string name;
        string symbol;
        uint256 balance;
        uint256 allowance;
        uint256 treasuryBalance;
        uint256 treasuryValueDre;
        uint8 decimals;
    }

    struct StakingPositionInfo {
        address owner;
        uint256 id;
        uint256 amount;
        uint256 declaredValue;
        uint256 rewards;
        uint256 cooldownEnd;
        uint256 rewardsUnlockAt;
        bool isActive;
    }

    struct BondPositionInfo {
        uint256 id;
        uint256 bondId;
        uint256 amount; // amount of DRE tokens
        uint256 quoteAmount; // amount of quote tokens paid
        uint256 startTime; // when the bond was purchased
        uint256 lastClaimTime; // last time tokens were claimed
        uint256 claimedAmount; // amount of tokens already claimed
        uint256 claimableAmount; // amount of tokens that can be claimed
        bool isStaked; // whether the position is staked
    }

    struct BondVariables {
        uint256 capacity; // capacity remaining in quote tokens
        IERC20 quoteToken; // token to accept as payment
        uint256 totalDebt; // total debt from bond
        uint256 maxPayout; // max tokens in/out
        uint256 sold; // DRE tokens out
        uint256 purchased; // quote tokens in
        uint256 startTime; // when the bond starts
        uint256 endTime; // when the bond ends
        uint256 initialPrice; // starting price in quote token
        uint256 finalPrice; // ending price in quote token
        uint256 currentPrice; // current price in quote token
    }

    struct ProtocolInfo {
        uint256 tvl;
        uint256 totalSupply;
        uint256 totalStaked;
        uint256 totalRewards;
        uint256 currentAPR;
        mapping(address => TokenInfo) tokenBalances;
        StakingPositionInfo[] stakingPositions;
        BondPositionInfo[] bondPositions;
    }

    // State variables
    IDreStaking public staking;
    IDreBondDepository public bondDepository;
    IDreTreasury public treasury;
    IERC20 public dreToken;
    IERC20 public stakingToken;
    IRebaseController public rebaseController;

    // Events
    event RewardsClaimed(uint256 indexed positionId, uint256 amount);

    constructor(
        address _staking,
        address _bondDepository,
        address _treasury,
        address _dreToken,
        address _stakingToken,
        address _rebaseController
    ) {
        staking = IDreStaking(_staking);
        bondDepository = IDreBondDepository(_bondDepository);
        treasury = IDreTreasury(_treasury);
        dreToken = IERC20(_dreToken);
        stakingToken = IERC20(_stakingToken);
        rebaseController = IRebaseController(_rebaseController);
    }

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
            TokenInfo[] memory tokenInfos,
            StakingPositionInfo[] memory stakingPositions,
            BondPositionInfo[] memory bondPositions
        )
    {
        // Get protocol-wide stats
        tvl = treasury.totalReserves();
        totalSupply = dreToken.totalSupply();
        totalStaked = staking.totalStaked();
        totalRewards = staking.rewardPerToken();
        currentAPR = calculateAPR();

        // Get token balances and allowances
        tokenInfos = new TokenInfo[](bondTokens.length + 2); // +1 for DRE token, +1 for staking token

        // Add DRE token info
        tokenInfos[0] = TokenInfo({
            token: address(dreToken),
            name: "DRE",
            symbol: "DRE",
            balance: dreToken.balanceOf(user),
            allowance: dreToken.allowance(user, address(staking)),
            treasuryBalance: 0,
            treasuryValueDre: 0,
            decimals: 18
        });

        // Add staking token info

        tokenInfos[1] = TokenInfo({
            token: address(stakingToken),
            name: "Staked DRE",
            symbol: "sDRE",
            balance: stakingToken.balanceOf(user),
            allowance: stakingToken.allowance(user, address(staking)),
            treasuryBalance: 0,
            treasuryValueDre: 0,
            decimals: 18
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
                treasuryValueDre: treasury.tokenValueE18(address(token), token.balanceOf(address(treasury))),
                token: address(token)
            });
        }

        // Get staking positions
        uint256 stakingBalance = staking.balanceOf(user);
        stakingPositions = new StakingPositionInfo[](stakingBalance);

        for (uint256 i = 0; i < stakingBalance; i++) {
            uint256 tokenId = staking.tokenOfOwnerByIndex(user, i);
            if (tokenId == 0) continue;
            IDreStaking.Position memory position = staking.positions(tokenId);

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

        // Get bond positions
        uint256 bondBalance = bondDepository.balanceOf(user);
        bondPositions = new BondPositionInfo[](bondBalance);

        for (uint256 i = 0; i < bondBalance; i++) {
            uint256 tokenId = bondDepository.tokenOfOwnerByIndex(user, i);
            IDreBondDepository.BondPosition memory position = bondDepository.positions(tokenId);

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

    /// @notice Claim all rewards for a staking position
    /// @return amount The amount of rewards claimed
    function claimAllRewards(address user) external returns (uint256 amount) {
        uint256 balance = staking.balanceOf(user);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = staking.tokenOfOwnerByIndex(user, i);
            if (tokenId == 0) continue;
            // IDreStaking.Position memory position = staking.positions(tokenId);
            // if (position.cooldownEnd > block.timestamp) continue;
            amount += staking.claimRewards(tokenId);
        }
    }

    /// @notice Calculate the current APR
    /// @return The current APR as a percentage (e.g., 1000 = 10%)
    function calculateAPR() public view returns (uint256) {
        (uint256 apr,,) = rebaseController.projectedEpochRate();
        return apr;
    }

    function getAllStakingPositions(uint256 startingIndex, uint256 endingIndex)
        external
        view
        returns (StakingPositionInfo[] memory)
    {
        StakingPositionInfo[] memory positions = new StakingPositionInfo[](endingIndex - startingIndex);

        for (uint256 i = startingIndex; i < endingIndex; i++) {
            IDreStaking.Position memory position = staking.positions(i);

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
        returns (IDreBondDepository.Bond[] memory bonds, uint256[] memory currentPrices)
    {
        bonds = new IDreBondDepository.Bond[](bondIds.length);
        currentPrices = new uint256[](bondIds.length);

        for (uint256 i = 0; i < bondIds.length; i++) {
            IDreBondDepository.Bond memory bond = bondDepository.bonds(bondIds[i]);
            bonds[i] = bond;
            currentPrices[i] = bondDepository.currentPrice(bondIds[i]);
        }
    }
}
