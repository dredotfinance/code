// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.7.5;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./libraries/Multicall.sol";
import "./libraries/SafeERC20.sol";
import "./types/DreAccessControlled.sol";
import "./interfaces/IDreStaking.sol";

// Permissioned ERC20 for tracking events
interface IPermissionedERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract DreStaking is IDreStaking, DreAccessControlled, ERC721Upgradeable, ReentrancyGuardUpgradeable, Multicall {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant HARBERGER_TAX_RATE = 500; // 5%
    uint256 public constant TEAM_TREASURY_SHARE = 100; // 1% (1% from harberger + 1% from resell)
    uint256 public constant TREASURY_SHARE = 400; // 4% from harberger
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant WITHDRAW_COOLDOWN_PERIOD = 3 days;
    uint256 public constant REWARD_COOLDOWN_PERIOD = 3 days;
    uint256 public constant DURATION = 8 hours;

    // State variables
    IERC20 public dreToken;
    IPermissionedERC20 public trackingToken;

    // Mapping from token ID to Position
    mapping(uint256 => Position) public positions;

    // Reward tracking
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public override totalStaked;

    function initialize(address _dreToken, address _trackingToken, IDreAuthority _authority) public initializer {
        __ERC721_init("DRE Staking Position", "DRE-POS");
        __ReentrancyGuard_init();

        require(_dreToken != address(0), "Invalid DRE token address");
        require(_trackingToken != address(0), "Invalid tracking token address");

        dreToken = IERC20(_dreToken);
        trackingToken = IPermissionedERC20(_trackingToken);
        _setAuthority(_authority);
    }

    function lastTimeRewardApplicable() public view override returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view override returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
    }

    /**
     * @notice Notify the contract of new rewards to be distributed
     * @param reward Amount of rewards to distribute over the next 8 hours
     */
    function notifyRewardAmount(uint256 reward) external override onlyPolicy {
        require(reward > 0, "No reward");
        require(totalStaked > 0, "No stakers");

        // Update rewards
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        dreToken.safeTransferFrom(msg.sender, address(this), reward);

        // Calculate new reward rate
        uint256 remaining = periodFinish > block.timestamp ? periodFinish - block.timestamp : 0;
        uint256 leftover = remaining * rewardRate;
        rewardRate = (reward + leftover) / DURATION;

        // Update period finish
        periodFinish = block.timestamp + DURATION;

        emit RewardAdded(reward);
    }

    /**
     * @notice Create a new position
     * @param to The address to mint the position to
     * @param amount The amount of DRE to stake
     * @param declaredValue The declared value of the position
     * @param minLockDuration The minimum time tokens must be locked (0 for no minimum)
     * @return tokenId The token ID of the new position
     */
    function createPosition(address to, uint256 amount, uint256 declaredValue, uint256 minLockDuration)
        external
        override
        nonReentrant
        returns (uint256 tokenId)
    {
        require(amount > 0, "Amount must be greater than 0");
        require(declaredValue > 0, "Declared value must be greater than 0");

        // Transfer DRE tokens from user
        dreToken.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate and collect harberger tax
        _distributeTax(declaredValue);

        // Create new position
        tokenId = totalSupply() + 1;
        _safeMint(to, tokenId);

        positions[tokenId] = Position({
            amount: amount,
            declaredValue: declaredValue,
            lastRewardUpdate: block.timestamp,
            rewardPerTokenPaid: rewardPerTokenStored,
            rewards: 0,
            cooldownEnd: 0,
            isInCooldown: false,
            rewardLockTime: 0,
            minLockDuration: minLockDuration
        });

        totalStaked += amount;
        _updateReward(tokenId);

        // Mint tracking tokens for the staked amount
        trackingToken.mint(to, amount);

        emit PositionCreated(tokenId, to, amount, declaredValue);
    }

    /**
     * @notice Start the unstaking process
     * @param tokenId The position ID
     */
    function startUnstaking(uint256 tokenId) external override nonReentrant {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not owner or approved");
        require(!positions[tokenId].isInCooldown, "Already in cooldown");

        Position storage position = positions[tokenId];

        // Check if minimum lock duration has passed
        require(block.timestamp >= position.minLockDuration, "Minimum lock duration not met");

        _updateReward(tokenId);

        position.isInCooldown = true;
        position.cooldownEnd = block.timestamp + WITHDRAW_COOLDOWN_PERIOD;
        position.rewardLockTime = block.timestamp; // Lock rewards at this time

        emit CooldownStarted(tokenId, msg.sender);
    }

    /**
     * @notice Complete the unstaking process
     * @param tokenId The position ID
     */
    function completeUnstaking(uint256 tokenId) external override nonReentrant {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not owner or approved");

        Position storage position = positions[tokenId];
        require(position.isInCooldown, "Not in cooldown");
        require(block.timestamp >= position.cooldownEnd, "Cooldown not finished");

        _updateReward(tokenId);

        uint256 amount = position.amount;
        totalStaked -= amount;

        // Burn tracking tokens for the unstaked amount
        trackingToken.burn(msg.sender, amount);

        // Transfer DRE tokens back to user
        dreToken.safeTransfer(msg.sender, amount);

        // Burn the NFT
        _burn(tokenId);
        delete positions[tokenId];

        emit PositionUnstaked(tokenId, msg.sender, amount);
    }

    /**
     * @notice Buy a position
     * @param tokenId The position ID
     */
    function buyPosition(uint256 tokenId) external override nonReentrant {
        require(_exists(tokenId), "Position does not exist");
        address seller = ownerOf(tokenId);
        require(seller != msg.sender, "Cannot buy your own position");

        Position storage position = positions[tokenId];
        uint256 price = position.declaredValue;

        // Calculate resell fee
        uint256 resellFee = (price * TEAM_TREASURY_SHARE) / BASIS_POINTS;
        uint256 sellerAmount = price - resellFee;

        // Transfer DRE tokens from buyer
        dreToken.safeTransferFrom(msg.sender, address(this), price);

        // Distribute payment
        dreToken.safeTransfer(seller, sellerAmount);
        dreToken.safeTransfer(authority.operationsTreasury(), resellFee);

        // Burn tracking tokens from seller and mint to buyer
        trackingToken.burn(seller, position.amount);
        trackingToken.mint(msg.sender, position.amount);

        // Transfer NFT to buyer
        _transfer(seller, msg.sender, tokenId);

        _cancelUnstaking(tokenId);

        emit PositionSold(tokenId, seller, msg.sender, price);
    }

    /**
     * @notice Claim rewards for a position
     * @param tokenId The position ID
     */
    function claimRewards(uint256 tokenId) external override nonReentrant returns (uint256 reward) {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not owner or approved");

        Position storage position = positions[tokenId];
        require(block.timestamp >= position.lastRewardUpdate + REWARD_COOLDOWN_PERIOD, "Rewards in cooldown");
        require(!position.isInCooldown, "Position is in cooldown");

        _updateReward(tokenId);

        reward = position.rewards;
        if (reward > 0) {
            position.rewards = 0;
            dreToken.safeTransfer(msg.sender, reward);
            emit RewardsClaimed(tokenId, msg.sender, reward);
        }
    }

    /**
     * @notice Get the claimable rewards for a position
     * @param tokenId The position ID
     * @return The claimable rewards
     */
    function getClaimableRewards(uint256 tokenId) external view override returns (uint256) {
        Position storage position = positions[tokenId];
        if (position.amount == 0) return 0;

        uint256 effectiveTime = block.timestamp;
        if (position.rewardLockTime > 0 && position.rewardLockTime < effectiveTime) {
            effectiveTime = position.rewardLockTime;
        }
        uint256 currentRewardPerToken = rewardPerTokenStored;
        if (totalStaked > 0) {
            uint256 timeElapsed = effectiveTime - lastUpdateTime;
            uint256 reward = timeElapsed * rewardRate;
            currentRewardPerToken += ((reward * 1e18) / totalStaked);
        }
        return (position.amount * (currentRewardPerToken - position.rewardPerTokenPaid)) / 1e18 + position.rewards;
    }

    /**
     * @notice Increase the staked amount for a position
     * @param tokenId The position ID
     * @param additionalAmount The amount to add to the stake
     * @param addtionalDeclaredValue The additional declared value
     */
    function increaseAmount(uint256 tokenId, uint256 additionalAmount, uint256 addtionalDeclaredValue)
        external
        override
        nonReentrant
    {
        require(_exists(tokenId), "Position does not exist");
        require(additionalAmount > 0, "Amount must be greater than 0");
        require(!positions[tokenId].isInCooldown, "Position is in cooldown");

        Position storage position = positions[tokenId];
        address owner = ownerOf(tokenId);

        // Transfer DRE tokens from user
        if (additionalAmount > 0) {
            dreToken.safeTransferFrom(msg.sender, address(this), additionalAmount);
        }

        // Calculate harberger tax on the additional amount
        _distributeTax(addtionalDeclaredValue);

        _updateReward(tokenId);

        // Update position
        position.amount += additionalAmount;
        position.declaredValue += addtionalDeclaredValue;
        totalStaked += additionalAmount;

        // Update rewards
        _updateReward(tokenId);

        // Mint tracking tokens for the additional amount
        trackingToken.mint(owner, additionalAmount);

        emit PositionUpdated(tokenId, owner, position.amount, position.declaredValue);
    }

    /**
     * @notice Cancel the unstaking process and reset cooldown variables
     * @param tokenId The position ID
     */
    function cancelUnstaking(uint256 tokenId) external override nonReentrant {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not owner or approved");

        Position storage position = positions[tokenId];
        require(position.isInCooldown, "Not in cooldown");

        // Update rewards to resume accrual
        _cancelUnstaking(tokenId);
    }

    /**
     * @notice Cancel the unstaking process and reset cooldown variables
     * @param tokenId The position ID
     */
    function _cancelUnstaking(uint256 tokenId) internal {
        Position storage position = positions[tokenId];
        position.isInCooldown = false;
        position.cooldownEnd = 0;
        position.rewardLockTime = 0;

        // Update rewards to resume accrual
        _updateReward(tokenId);

        emit UnstakingCancelled(tokenId, msg.sender);
    }

    /**
     * @notice Override the beforeTokenTransfer function to prevent transfers
     * @param from The address the token is being transferred from
     * @param to The address the token is being transferred to
     * @param tokenId The ID of the token being transferred
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        require(msg.sender == address(this), "Only this contract can transfer");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @notice Distribute the tax to the operations treasury and protocol treasury
     * @param amount The amount of DRE to distribute
     */
    function _distributeTax(uint256 amount) internal {
        uint256 operationsShare = (amount * TEAM_TREASURY_SHARE) / BASIS_POINTS;
        uint256 treasuryShare = amount - operationsShare;

        dreToken.safeTransfer(address(authority.operationsTreasury()), operationsShare);
        dreToken.safeTransfer(address(authority.treasury()), treasuryShare);
    }

    /**
     * @notice Update the reward for a position
     * @param tokenId The position ID
     */
    function _updateReward(uint256 tokenId) internal {
        Position storage position = positions[tokenId];
        uint256 effectiveTime = block.timestamp;
        if (position.rewardLockTime > 0 && position.rewardLockTime < effectiveTime) {
            effectiveTime = position.rewardLockTime;
        }

        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (position.amount > 0) {
            position.rewards = (position.amount * (rewardPerTokenStored - position.rewardPerTokenPaid)) / 1e18;
            position.rewardPerTokenPaid = rewardPerTokenStored;
        }
        position.lastRewardUpdate = effectiveTime;
    }
}
