// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/// @title IDreStaking
/// @notice Interface for the DRE Staking contract that manages token staking and rewards
/// @dev Handles staking operations, reward distribution, and staking state management
interface IDreStaking is IERC721Enumerable {
    // Structs
    struct Position {
        uint256 amount; // Amount of DRE staked
        uint256 declaredValue; // Self-declared value in DRE
        uint256 rewardPerTokenPaid; // Reward per token paid
        uint256 rewards; // Accumulated rewards
        uint256 cooldownEnd; // When cooldown period ends; if 0, position is not in cooldown
        uint256 rewardsUnlockAt; // If >0, rewards can't be claimed before this time
    }

    // Events
    /// @notice Emitted when a user stakes tokens
    /// @param user Address of the user
    /// @param amount Amount of tokens staked
    event Staked(address indexed user, uint256 amount);

    /// @notice Emitted when a user unstakes tokens
    /// @param user Address of the user
    /// @param amount Amount of tokens unstaked
    event Unstaked(address indexed user, uint256 amount);

    /// @notice Emitted when rewards are distributed
    /// @param amount Amount of rewards distributed
    event RewardsDistributed(uint256 amount);

    /// @notice Emitted when a position is created
    /// @param tokenId Token ID of the position
    /// @param owner Address of the owner
    /// @param amount Amount of DRE staked
    /// @param declaredValue Self-declared value in DRE
    event PositionCreated(uint256 indexed tokenId, address indexed owner, uint256 amount, uint256 declaredValue);

    /// @notice Emitted when a position is sold
    /// @param tokenId Token ID of the position
    /// @param seller Address of the seller
    /// @param buyer Address of the buyer
    /// @param price Price of the position
    event PositionSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);

    /// @notice Emitted when rewards are claimed
    /// @param tokenId Token ID of the position
    /// @param owner Address of the owner
    /// @param amount Amount of rewards claimed
    event RewardsClaimed(uint256 indexed tokenId, address indexed owner, uint256 amount);

    /// @notice Emitted when a position is unstaked
    /// @param tokenId Token ID of the position
    /// @param owner Address of the owner
    /// @param amount Amount of DRE unstaked
    event PositionUnstaked(uint256 indexed tokenId, address indexed owner, uint256 amount);

    /// @notice Emitted when a cooldown period starts
    /// @param tokenId Token ID of the position
    /// @param owner Address of the owner
    event CooldownStarted(uint256 indexed tokenId, address indexed owner);

    /// @notice Emitted when a cooldown period ends
    /// @param tokenId Token ID of the position
    /// @param owner Address of the owner
    event CooldownEnded(uint256 indexed tokenId, address indexed owner);

    /// @notice Emitted when a position is updated
    /// @param tokenId Token ID of the position
    /// @param owner Address of the owner
    /// @param newAmount New amount of DRE staked
    /// @param newDeclaredValue New self-declared value in DRE
    event PositionUpdated(uint256 indexed tokenId, address indexed owner, uint256 newAmount, uint256 newDeclaredValue);

    /// @notice Emitted when unstaking is cancelled
    /// @param tokenId Token ID of the position
    /// @param owner Address of the owner
    event UnstakingCancelled(uint256 indexed tokenId, address indexed owner);

    /// @notice Emitted when a reward is added
    /// @param reward Amount of reward added
    event RewardAdded(uint256 reward);

    /// @notice Emitted when a reward is paid
    /// @param user Address of the user
    /// @param reward Amount of reward paid
    event RewardPaid(address indexed user, uint256 reward);

    // View functions
    /// @notice Gets the last time rewards are applicable
    /// @return uint256 Last time rewards are applicable
    function lastTimeRewardApplicable() external view returns (uint256);

    /// @notice Gets the reward per token
    /// @return uint256 Reward per token
    function rewardPerToken() external view returns (uint256);

    /// @notice Gets the earned rewards for a token
    /// @param tokenId Token ID of the position
    /// @return uint256 Amount of earned rewards
    function earned(uint256 tokenId) external view returns (uint256);

    /// @notice Gets the burner address
    /// @return address Burner address
    function burner() external view returns (address);

    /// @notice Gets the total amount of tokens staked
    /// @return uint256 Total staked amount
    function totalStaked() external view returns (uint256);

    // State changing functions
    /// @notice Distributes rewards
    /// @param reward Amount of rewards to distribute
    function notifyRewardAmount(uint256 reward) external;

    /// @notice Creates a new position
    /// @param _user Address of the user
    /// @param _amount Amount of DRE to stake
    /// @param _declaredValue Self-declared value in DRE
    /// @param _lockEnd End time of the lock period
    /// @return tokenId Token ID of the created position
    /// @return taxPaid Amount of tax paid
    function createPosition(address _user, uint256 _amount, uint256 _declaredValue, uint256 _lockEnd)
        external
        returns (uint256 tokenId, uint256 taxPaid);

    /// @notice Starts the unstaking process
    /// @param tokenId Token ID of the position
    function startUnstaking(uint256 tokenId) external;

    /// @notice Completes the unstaking process
    /// @param tokenId Token ID of the position
    function completeUnstaking(uint256 tokenId) external;

    /// @notice Buys a position
    /// @param tokenId Token ID of the position
    function buyPosition(uint256 tokenId) external;

    /// @notice Claims rewards for a position
    /// @param tokenId Token ID of the position
    /// @return reward Amount of claimed rewards
    function claimRewards(uint256 tokenId) external returns (uint256 reward);

    /// @notice Increases the amount of a position
    /// @param tokenId Token ID of the position
    /// @param additionalAmount Additional amount of DRE to stake
    /// @param addtionalDeclaredValue Additional self-declared value in DRE
    function increaseAmount(uint256 tokenId, uint256 additionalAmount, uint256 addtionalDeclaredValue) external;

    /// @notice Cancels the unstaking process
    /// @param tokenId Token ID of the position
    function cancelUnstaking(uint256 tokenId) external;

    /// @notice Gets a position
    /// @param tokenId Token ID of the position
    /// @return Position Position information
    function positions(uint256 tokenId) external view returns (Position memory);

    /// @notice Gets the reward rate
    /// @return uint256 Reward rate
    function rewardRate() external view returns (uint256);
}
