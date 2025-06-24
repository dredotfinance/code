// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IAppStaking
/// @notice Interface for the staking system that allows users to stake RZR tokens and earn rewards
/// @dev This interface extends IERC721Enumerable to provide NFT functionality for staking positions
interface IAppStaking is IERC721Enumerable {
    // Structs
    /// @notice Represents a staking position
    /// @param amount Amount of RZR tokens staked in the position
    /// @param declaredValue Self-declared value in RZR for harberger tax
    /// @param rewardPerTokenPaid Last reward per token paid to this position
    /// @param rewards Accumulated rewards for this position
    /// @param cooldownEnd Timestamp when cooldown period ends; if 0, position is not in cooldown
    /// @param rewardsUnlockAt Timestamp when rewards can be claimed; if >0, rewards can't be claimed before this time
    struct Position {
        uint256 amount;
        uint256 declaredValue;
        uint256 rewardPerTokenPaid;
        uint256 rewards;
        uint256 cooldownEnd;
        uint256 rewardsUnlockAt;
    }

    // Events
    /// @notice Emitted when a new staking position is created
    /// @param tokenId The ID of the created position NFT
    /// @param owner The address of the position owner
    /// @param amount The amount of RZR tokens staked
    /// @param declaredValue The self-declared value for harberger tax
    event PositionCreated(uint256 indexed tokenId, address indexed owner, uint256 amount, uint256 declaredValue);

    /// @notice Emitted when a staking position is sold
    /// @param tokenId The ID of the position NFT
    /// @param seller The address of the seller
    /// @param buyer The address of the buyer
    /// @param price The price paid for the position
    event PositionSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);

    /// @notice Emitted when rewards are claimed from a position
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    /// @param amount The amount of rewards claimed
    event RewardsClaimed(uint256 indexed tokenId, address indexed owner, uint256 amount);

    /// @notice Emitted when tokens are unstaked from a position
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    /// @param amount The amount of tokens unstaked
    event PositionUnstaked(uint256 indexed tokenId, address indexed owner, uint256 amount);

    /// @notice Emitted when a position enters cooldown period
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    event CooldownStarted(uint256 indexed tokenId, address indexed owner);

    /// @notice Emitted when a position's cooldown period ends
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    event CooldownEnded(uint256 indexed tokenId, address indexed owner);

    /// @notice Emitted when a position is updated
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    /// @param newAmount The new amount of tokens staked
    /// @param newDeclaredValue The new declared value
    event PositionUpdated(uint256 indexed tokenId, address indexed owner, uint256 newAmount, uint256 newDeclaredValue);

    /// @notice Emitted when unstaking is cancelled
    /// @param tokenId The ID of the position NFT
    /// @param owner The address of the position owner
    event UnstakingCancelled(uint256 indexed tokenId, address indexed owner);

    /// @notice Emitted when new rewards are added to the staking pool
    /// @param reward The amount of rewards added
    event RewardAdded(uint256 reward);

    /// @notice Emitted when rewards are paid to a user
    /// @param user The address of the user receiving rewards
    /// @param reward The amount of rewards paid
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice Emitted when harberger tax rate is updated
    /// @param oldValue The old harberger tax rate
    /// @param newValue The new harberger tax rate
    event HarbergerTaxRateUpdated(uint256 oldValue, uint256 newValue);

    /// @notice Emitted when staking fee rate is updated
    /// @param oldValue The old staking fee rate
    /// @param newValue The new staking fee rate
    event StakingFeeRateUpdated(uint256 oldValue, uint256 newValue);

    /// @notice Emitted when basis points is updated
    /// @param oldValue The old basis points
    /// @param newValue The new basis points
    event BasisPointsUpdated(uint256 oldValue, uint256 newValue);

    /// @notice Emitted when withdraw cooldown period is updated
    /// @param oldValue The old withdraw cooldown period
    /// @param newValue The new withdraw cooldown period
    event WithdrawCooldownPeriodUpdated(uint256 oldValue, uint256 newValue);

    /// @notice Emitted when reward cooldown period is updated
    /// @param oldValue The old reward cooldown period
    /// @param newValue The new reward cooldown period
    event RewardCooldownPeriodUpdated(uint256 oldValue, uint256 newValue);

    /// @notice Emitted when buy cooldown period is updated
    /// @param oldValue The old buy cooldown period
    /// @param newValue The new buy cooldown period
    event BuyCooldownPeriodUpdated(uint256 oldValue, uint256 newValue);

    /// @notice Emitted when epoch duration is updated
    /// @param oldValue The old epoch duration
    /// @param newValue The new epoch duration
    event EpochDurationUpdated(uint256 oldValue, uint256 newValue);

    /// @notice Emitted when a position is split
    /// @param originalTokenId The ID of the original position NFT
    /// @param newTokenId The ID of the new position NFT
    /// @param owner The address of the position owner
    /// @param to The address to which the new position is split
    /// @param splitAmount The amount of tokens split
    /// @param splitDeclaredValue The declared value of the split position
    event PositionSplit(
        uint256 indexed originalTokenId,
        uint256 indexed newTokenId,
        address indexed owner,
        address to,
        uint256 splitAmount,
        uint256 splitDeclaredValue
    );

    /// @notice Emitted when a position is merged
    /// @param survivingTokenId The ID of the surviving position NFT
    /// @param mergedTokenId The ID of the merged position NFT
    /// @param owner The address of the position owner
    /// @param newAmount The new amount of tokens staked in the merged position
    /// @param newDeclaredValue The new declared value for harberger tax in the merged position
    event PositionMerged(
        uint256 indexed survivingTokenId,
        uint256 indexed mergedTokenId,
        address indexed owner,
        uint256 newAmount,
        uint256 newDeclaredValue
    );

    /// @notice Initializes the staking contract
    /// @param _appToken The address of the dre token
    /// @param _trackingToken The address of the tracking token
    /// @param _authority The address of the authority contract
    /// @param _burner The address of the burner contract
    function initialize(address _appToken, address _trackingToken, address _authority, address _burner) external;

    // View functions
    /// @notice Gets the last time rewards were applicable
    /// @return The timestamp of the last reward application
    function lastTimeRewardApplicable() external view returns (uint256);

    /// @notice Gets the current reward per token rate
    /// @return The reward per token rate
    function rewardPerToken() external view returns (uint256);

    /// @notice Gets the earned rewards for a specific position
    /// @param tokenId The ID of the position NFT
    /// @return The amount of rewards earned
    function earned(uint256 tokenId) external view returns (uint256);

    /// @notice Gets the total amount of tokens staked
    /// @return The total amount of staked tokens
    function totalStaked() external view returns (uint256);

    // State changing functions
    /// @notice Notifies the contract of new rewards to be distributed
    /// @param reward The amount of rewards to be distributed
    function notifyRewardAmount(uint256 reward) external;

    /// @notice Creates a new staking position
    /// @param _user The address of the user creating the position
    /// @param _amount The amount of tokens to stake
    /// @param _declaredValue The self-declared value for harberger tax
    /// @param _lockEnd The timestamp when the lock period ends
    /// @return tokenId The ID of the created position NFT
    /// @return taxPaid The amount of tax paid for the position
    function createPosition(address _user, uint256 _amount, uint256 _declaredValue, uint256 _lockEnd)
        external
        returns (uint256 tokenId, uint256 taxPaid);

    /// @notice Starts the unstaking process for a position
    /// @param tokenId The ID of the position NFT
    function startUnstaking(uint256 tokenId) external;

    /// @notice Completes the unstaking process for a position
    /// @param tokenId The ID of the position NFT
    function completeUnstaking(uint256 tokenId) external;

    /// @notice Buys a staking position
    /// @param tokenId The ID of the position NFT to buy
    function buyPosition(uint256 tokenId) external;

    /// @notice Claims rewards from a staking position
    /// @param tokenId The ID of the position NFT
    /// @return reward The amount of rewards claimed
    function claimRewards(uint256 tokenId) external returns (uint256 reward);

    /// @notice Increases the amount of tokens staked in a position
    /// @param tokenId The ID of the position NFT
    /// @param additionalAmount The additional amount of tokens to stake
    /// @param addtionalDeclaredValue The additional declared value
    /// @return taxPaid The amount of tax paid for the additional amount
    function increaseAmount(uint256 tokenId, uint256 additionalAmount, uint256 addtionalDeclaredValue)
        external
        returns (uint256 taxPaid);

    /// @notice Cancels the unstaking process for a position
    /// @param tokenId The ID of the position NFT
    function cancelUnstaking(uint256 tokenId) external;

    /// @notice Gets the details of a staking position
    /// @param tokenId The ID of the position NFT
    /// @return The position details
    function positions(uint256 tokenId) external view returns (Position memory);

    /// @notice Gets the current reward rate
    /// @return The current reward rate
    function rewardRate() external view returns (uint256);

    /// @notice Gets the current reward per token rate
    /// @return The current reward per token rate
    function rewardPerTokenStored() external view returns (uint256);

    /// @notice Gets the last time rewards were applicable
    /// @return The timestamp of the last reward application
    function lastUpdateTime() external view returns (uint256);

    /// @notice Gets the current reward rate
    /// @return The current reward rate
    function periodFinish() external view returns (uint256);

    /// @notice Gets the address of the burner contract
    /// @return The address of the burner contract
    function burner() external view returns (address);

    /// @notice Gets the harberger tax rate
    /// @return The harberger tax rate
    function harbergerTaxRate() external view returns (uint256);

    /// @notice Gets the withdraw cooldown period
    /// @return The withdraw cooldown period
    function withdrawCooldownPeriod() external view returns (uint256);

    /// @notice Gets the reward cooldown period
    /// @return The reward cooldown period
    function rewardCooldownPeriod() external view returns (uint256);

    /// @notice Checks if a bond position is in cooldown (vesting period)
    /// @param _tokenId The ID of the bond position NFT
    /// @return bool True if the position is in cooldown, false otherwise
    function isInBuyCooldown(uint256 _tokenId) external view returns (bool);

    /// @notice Gets the epoch duration
    /// @return The epoch duration
    function EPOCH_DURATION() external view returns (uint256);

    /// @notice Gets the app token
    /// @return The app token
    function appToken() external view returns (IERC20);

    /// @notice Splits a position into two positions, sending the new position to a specified address
    /// @param tokenId The ID of the position to split
    /// @param splitRatio The ratio to split the position
    /// @param to The address to receive the new position
    /// @return newTokenId The ID of the newly created position
    function splitPosition(uint256 tokenId, uint256 splitRatio, address to) external returns (uint256 newTokenId);

    /// @notice Merges two positions owned by the caller into a single position.
    /// @param tokenId1 The ID of the first position NFT (this one will survive).
    /// @param tokenId2 The ID of the second position NFT (this one will be burned).
    /// @return mergedTokenId The ID of the resulting merged position (equals tokenId1)
    function mergePositions(uint256 tokenId1, uint256 tokenId2) external returns (uint256 mergedTokenId);

    /// @notice Increases only the declared (buy-out) value of a position and pays the corresponding Harberger tax.
    /// @param tokenId The ID of the position NFT
    /// @param additionalDeclaredValue The additional declared value to add (in RZR)
    /// @return taxPaid The amount of tax paid for the declared value increment
    function increaseDeclaredValue(uint256 tokenId, uint256 additionalDeclaredValue)
        external
        returns (uint256 taxPaid);
}
