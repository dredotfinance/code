// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IDreStaking {
    // Structs
    struct Position {
        uint256 amount; // Amount of DRE staked
        uint256 declaredValue; // Self-declared value in DRE
        uint256 lastRewardUpdate; // Last time rewards were updated
        uint256 rewardPerTokenPaid; // Reward per token paid
        uint256 rewards; // Accumulated rewards
        uint256 cooldownEnd; // When cooldown period ends
        bool isInCooldown; // Whether position is in cooldown (for withdrawals)
        uint256 rewardLockTime; // If >0, rewards stop accruing after this time
        uint256 minLockDuration; // Minimum lock duration
    }

    // Events
    event PositionCreated(uint256 indexed tokenId, address indexed owner, uint256 amount, uint256 declaredValue);
    event PositionSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event RewardsClaimed(uint256 indexed tokenId, address indexed owner, uint256 amount);
    event PositionUnstaked(uint256 indexed tokenId, address indexed owner, uint256 amount);
    event CooldownStarted(uint256 indexed tokenId, address indexed owner);
    event CooldownEnded(uint256 indexed tokenId, address indexed owner);
    event PositionUpdated(uint256 indexed tokenId, address indexed owner, uint256 newAmount, uint256 newDeclaredValue);
    event UnstakingCancelled(uint256 indexed tokenId, address indexed owner);
    event RewardAdded(uint256 reward);
    event RewardPaid(address indexed user, uint256 reward);

    // View functions
    function lastTimeRewardApplicable() external view returns (uint256);

    function rewardPerToken() external view returns (uint256);

    function getClaimableRewards(uint256 tokenId) external view returns (uint256);

    function totalStaked() external view returns (uint256);

    // State changing functions
    function notifyRewardAmount(uint256 reward) external;

    function createPosition(
        address to,
        uint256 amount,
        uint256 declaredValue,
        uint256 lockTime
    ) external returns (uint256 tokenId);

    function startUnstaking(uint256 tokenId) external;

    function completeUnstaking(uint256 tokenId) external;

    function buyPosition(uint256 tokenId) external;

    function claimRewards(uint256 tokenId) external returns (uint256 reward);

    function increaseAmount(uint256 tokenId, uint256 additionalAmount, uint256 addtionalDeclaredValue) external;

    function cancelUnstaking(uint256 tokenId) external;
}
