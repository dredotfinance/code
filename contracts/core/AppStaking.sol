// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IAppStaking.sol";
import "../interfaces/IPermissionedERC20.sol";
import "./AppAccessControlled.sol";

/// @title AppStaking
/// @notice Implementation of the staking system that allows users to stake RZR tokens and earn rewards
/// @dev This contract handles staking positions as NFTs, with harberger tax and reward distribution
contract AppStaking is
    IAppStaking,
    AppAccessControlled,
    ERC721EnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    MulticallUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 public immutable BASIS_POINTS = 10000;
    uint256 public immutable EPOCH_DURATION = 8 hours;

    // Configurable parameters
    uint256 public harbergerTaxRate;
    uint256 public resellFeeRate;
    uint256 public withdrawCooldownPeriod;
    uint256 public rewardCooldownPeriod;

    // State variables
    IERC20 public override appToken;
    IPermissionedERC20 public trackingToken;

    // Mapping from token ID to Position
    mapping(uint256 => Position) private _positions;

    uint256 public lastId;

    /// @inheritdoc IAppStaking
    uint256 public periodFinish;

    /// @inheritdoc IAppStaking
    uint256 public rewardRate;

    /// @inheritdoc IAppStaking
    uint256 public lastUpdateTime;

    /// @inheritdoc IAppStaking
    uint256 public rewardPerTokenStored;

    /// @inheritdoc IAppStaking
    uint256 public override totalStaked;

    /// @inheritdoc IAppStaking
    address public burner;

    /// @inheritdoc IAppStaking
    function initialize(address _dreToken, address _trackingToken, address _authority, address _burner)
        public
        initializer
    {
        if (lastId == 0) lastId = 1;

        __ERC721_init("RZR Staking Position", "RZR-POS");
        __ReentrancyGuard_init();
        __AppAccessControlled_init(_authority);

        uint256 _harbergerTaxRate = 500;
        uint256 _resellFeeRate = 100;
        uint256 _withdrawCooldownPeriod = 3 days;
        uint256 _rewardCooldownPeriod = 1 days;

        require(_dreToken != address(0), "Invalid RZR token address");
        require(_trackingToken != address(0), "Invalid tracking token address");
        require(_harbergerTaxRate <= BASIS_POINTS, "Invalid harberger tax rate");
        require(_resellFeeRate <= BASIS_POINTS, "Invalid resell fee rate");
        require(_withdrawCooldownPeriod > 0, "Invalid withdraw cooldown period");
        require(_rewardCooldownPeriod > 0, "Invalid reward cooldown period");

        appToken = IERC20(_dreToken);
        trackingToken = IPermissionedERC20(_trackingToken);
        burner = _burner;

        harbergerTaxRate = _harbergerTaxRate;
        resellFeeRate = _resellFeeRate;
        withdrawCooldownPeriod = _withdrawCooldownPeriod;
        rewardCooldownPeriod = _rewardCooldownPeriod;
    }

    /// @notice Sets the harberger tax rate
    /// @param _harbergerTaxRate The new harberger tax rate
    function setHarbergerTaxRate(uint256 _harbergerTaxRate) external onlyGovernor {
        require(_harbergerTaxRate <= BASIS_POINTS, "Invalid harberger tax rate");
        uint256 oldValue = harbergerTaxRate;
        harbergerTaxRate = _harbergerTaxRate;
        emit HarbergerTaxRateUpdated(oldValue, _harbergerTaxRate);
    }

    /// @notice Sets the withdraw cooldown period
    /// @param _withdrawCooldownPeriod The new withdraw cooldown period
    function setWithdrawCooldownPeriod(uint256 _withdrawCooldownPeriod) external onlyGovernor {
        require(_withdrawCooldownPeriod > 0, "Invalid withdraw cooldown period");
        uint256 oldValue = withdrawCooldownPeriod;
        withdrawCooldownPeriod = _withdrawCooldownPeriod;
        emit WithdrawCooldownPeriodUpdated(oldValue, _withdrawCooldownPeriod);
    }

    /// @notice Sets the reward cooldown period
    /// @param _rewardCooldownPeriod The new reward cooldown period
    function setRewardCooldownPeriod(uint256 _rewardCooldownPeriod) external onlyPolicy {
        require(_rewardCooldownPeriod > 0, "Invalid reward cooldown period");
        uint256 oldValue = rewardCooldownPeriod;
        rewardCooldownPeriod = _rewardCooldownPeriod;
        emit RewardCooldownPeriodUpdated(oldValue, _rewardCooldownPeriod);
    }

    /// @inheritdoc IAppStaking
    function positions(uint256 tokenId) external view override returns (Position memory) {
        return _positions[tokenId];
    }

    /// @inheritdoc IAppStaking
    function lastTimeRewardApplicable() public view override returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @inheritdoc IAppStaking
    function rewardPerToken() public view override returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        // Round down at each step to prevent over-distribution
        uint256 timeElapsed = lastTimeRewardApplicable() - lastUpdateTime;
        uint256 rewardPerTokenDelta = (timeElapsed * rewardRate * 1e18) / totalStaked;
        return rewardPerTokenStored + rewardPerTokenDelta;
    }

    /// @inheritdoc IAppStaking
    function notifyRewardAmount(uint256 reward) external override onlyPolicy {
        require(reward > 0, "No reward");
        require(totalStaked > 0, "No stakers");

        // Update rewards
        _updateReward(0);
        appToken.safeTransferFrom(msg.sender, address(this), reward);

        if (block.timestamp >= periodFinish) {
            // If no reward is currently being distributed, the new rate is just `reward / duration`
            rewardRate = reward / EPOCH_DURATION;
        } else {
            // Otherwise, cancel the future reward and add the amount left to distribute to reward
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / EPOCH_DURATION;
        }

        // Ensures the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of `rewardRate` in the earned and `rewardsPerToken` functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = appToken.balanceOf(address(this));
        require(rewardRate <= balance / EPOCH_DURATION, "Reward rate too high");

        // Update period finish
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + EPOCH_DURATION;

        emit RewardAdded(reward);
    }

    /// @inheritdoc IAppStaking
    function createPosition(address to, uint256 amount, uint256 declaredValue, uint256 minLockDuration)
        external
        override
        nonReentrant
        returns (uint256 tokenId, uint256 taxPaid)
    {
        require(amount > 0, "Amount must be greater than 0");
        require(declaredValue > 0, "Declared value must be greater than 0");

        // Transfer RZR tokens from user
        appToken.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate and collect harberger tax
        taxPaid = _distributeTax(declaredValue);
        amount -= taxPaid;

        // Create new position
        tokenId = lastId++;
        _mint(to, tokenId);

        _positions[tokenId] = Position({
            amount: amount,
            declaredValue: declaredValue,
            rewardPerTokenPaid: rewardPerTokenStored,
            rewards: 0,
            cooldownEnd: 0,
            rewardsUnlockAt: block.timestamp + Math.max(minLockDuration, rewardCooldownPeriod)
        });

        totalStaked += amount;
        _updateReward(tokenId);

        // Mint tracking tokens for the staked amount
        trackingToken.mint(to, amount);

        emit PositionCreated(tokenId, to, amount, declaredValue);
    }

    /// @inheritdoc IAppStaking
    function startUnstaking(uint256 tokenId) external override nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(_positions[tokenId].cooldownEnd == 0, "Already in cooldown");

        Position storage position = _positions[tokenId];
        _updateReward(tokenId);
        position.cooldownEnd = block.timestamp + withdrawCooldownPeriod;

        emit CooldownStarted(tokenId, msg.sender);
    }

    /// @inheritdoc IAppStaking
    function completeUnstaking(uint256 tokenId) external override nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        Position storage position = _positions[tokenId];
        require(position.cooldownEnd > 0, "Not in cooldown");
        require(block.timestamp >= position.cooldownEnd, "Cooldown not finished");

        _updateReward(tokenId);

        uint256 amount = position.amount;
        totalStaked -= amount;

        // Burn tracking tokens for the unstaked amount
        trackingToken.burn(msg.sender, amount);

        // Transfer RZR tokens back to user
        appToken.safeTransfer(msg.sender, amount);

        // Burn the NFT
        _burn(tokenId);
        delete _positions[tokenId];

        emit PositionUnstaked(tokenId, msg.sender, amount);
    }

    /// @inheritdoc IAppStaking
    function buyPosition(uint256 tokenId) external override nonReentrant {
        address seller = ownerOf(tokenId);
        require(seller != address(0), "Position does not exist");
        require(seller != msg.sender, "Cannot buy your own position");

        Position storage position = _positions[tokenId];
        uint256 price = position.declaredValue;

        // Calculate resell fee
        uint256 resellFee = (price * resellFeeRate) / BASIS_POINTS;
        uint256 sellerAmount = price - resellFee;

        // Transfer RZR tokens from buyer
        appToken.safeTransferFrom(msg.sender, address(this), price);

        // Distribute payment
        appToken.safeTransfer(seller, sellerAmount);
        appToken.safeTransfer(burner, resellFee);

        // Burn tracking tokens from seller and mint to buyer
        trackingToken.burn(seller, position.amount);
        trackingToken.mint(msg.sender, position.amount);

        // Transfer NFT to buyer
        _transfer(seller, msg.sender, tokenId);

        // Cancel unstaking and claim any pending rewards to avoid getting sniped
        _cancelUnstaking(tokenId);
        _claimRewards(tokenId);

        emit PositionSold(tokenId, seller, msg.sender, price);
    }

    /// @inheritdoc IAppStaking
    function claimRewards(uint256 tokenId) external override nonReentrant returns (uint256 reward) {
        reward = _claimRewards(tokenId);
    }

    /// @inheritdoc IAppStaking
    function earned(uint256 tokenId) public view override returns (uint256) {
        Position storage position = _positions[tokenId];
        if (position.amount == 0) return 0;

        uint256 currentRewardPerToken = rewardPerToken();
        // Round down at each step to prevent over-distribution
        uint256 rewardDelta = (position.amount * (currentRewardPerToken - position.rewardPerTokenPaid)) / 1e18;
        return rewardDelta + position.rewards;
    }

    /// @inheritdoc IAppStaking
    function increaseAmount(uint256 tokenId, uint256 additionalAmount, uint256 addtionalDeclaredValue)
        external
        override
        nonReentrant
    {
        require(ownerOf(tokenId) != address(0), "Position does not exist");
        require(additionalAmount > 0, "Amount must be greater than 0");
        require(_positions[tokenId].cooldownEnd == 0, "Position is in cooldown");

        Position storage position = _positions[tokenId];
        address owner = ownerOf(tokenId);

        // Transfer RZR tokens from user
        if (additionalAmount > 0) {
            appToken.safeTransferFrom(msg.sender, address(this), additionalAmount);
        }

        // Calculate harberger tax on the additional amount
        uint256 taxPaid = _distributeTax(addtionalDeclaredValue);
        additionalAmount -= taxPaid;
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

    /// @inheritdoc IAppStaking
    function cancelUnstaking(uint256 tokenId) external override nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        Position storage position = _positions[tokenId];
        require(position.cooldownEnd > 0, "Not in cooldown");

        // Update rewards to resume accrual
        _cancelUnstaking(tokenId);
    }

    /// @notice Cancels the unstaking process and resets cooldown variables
    /// @param tokenId The position ID
    function _cancelUnstaking(uint256 tokenId) internal {
        Position storage position = _positions[tokenId];

        if (position.cooldownEnd > 0) {
            _updateReward(tokenId);
            position.cooldownEnd = 0;
            position.rewardsUnlockAt = 0;
            emit UnstakingCancelled(tokenId, msg.sender);
        }

        _updateReward(tokenId);
    }

    /// @notice Claims rewards for a position
    /// @param tokenId The position ID
    /// @return reward The amount of rewards claimed
    function _claimRewards(uint256 tokenId) internal returns (uint256 reward) {
        Position storage position = _positions[tokenId];
        // require(block.timestamp >= position.rewardsUnlockAt, "Rewards in cooldown");

        _updateReward(tokenId);

        reward = position.rewards;
        if (reward > 0) {
            address owner = ownerOf(tokenId);
            position.rewards = 0;
            appToken.safeTransfer(owner, reward);
            emit RewardsClaimed(tokenId, owner, reward);
        }
    }

    /// @notice Overrides the beforeTokenTransfer function to prevent transfers
    /// @param to The address receiving the token
    /// @param tokenId The token ID
    /// @param auth The address authorized to transfer
    /// @return The address that should be the owner
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        require(auth == address(0), "Only mints/burns");
        return super._update(to, tokenId, auth);
    }

    /// @notice Distributes the tax to the operations treasury and protocol treasury
    /// @param amount The amount of RZR to distribute
    /// @return taxPaid The total amount of tax paid
    function _distributeTax(uint256 amount) internal returns (uint256 taxPaid) {
        taxPaid = (amount * harbergerTaxRate) / BASIS_POINTS;
        appToken.safeTransfer(burner, taxPaid); // burn the tax so that the floor price increases
    }

    /// @notice Updates the reward for a position
    /// @param tokenId The position ID
    function _updateReward(uint256 tokenId) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (tokenId > 0) {
            Position storage position = _positions[tokenId];
            position.rewards = earned(tokenId);
            position.rewardPerTokenPaid = rewardPerTokenStored;
        }
    }

    /// @inheritdoc IAppStaking
    function splitPosition(uint256 tokenId, uint256 splitRatio, address to)
        external
        override
        nonReentrant
        returns (uint256 newTokenId)
    {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(to != address(0), "Invalid recipient address");
        require(splitRatio > 0, "Split ratio must be greater than 0");
        require(splitRatio <= 1e18, "Split ratio must be less than or equal to 100%");

        Position storage position = _positions[tokenId];
        require(position.cooldownEnd == 0, "Position is in cooldown");

        // Update rewards for the original position
        _updateReward(tokenId);

        // Create new position
        newTokenId = lastId++;
        _mint(to, newTokenId);

        uint256 splitAmount = position.amount * splitRatio / 1e18;
        uint256 splitDeclaredValue = position.declaredValue * splitRatio / 1e18;

        // Create new position with split values
        _positions[newTokenId] = Position({
            amount: splitAmount,
            declaredValue: splitDeclaredValue,
            rewardPerTokenPaid: rewardPerTokenStored,
            rewards: 0,
            cooldownEnd: 0,
            rewardsUnlockAt: position.rewardsUnlockAt
        });

        // Update original position
        position.amount -= splitAmount;
        position.declaredValue -= splitDeclaredValue;

        // Update tracking tokens for the new position
        trackingToken.mint(to, splitAmount);
        trackingToken.burn(msg.sender, splitAmount);

        _updateReward(tokenId);
        _updateReward(newTokenId);

        emit PositionSplit(tokenId, newTokenId, msg.sender, to, splitAmount, splitDeclaredValue);
    }

    /// @notice Returns the base URI for the NFT metadata
    /// @return The base URI string
    function _baseURI() internal view virtual override returns (string memory) {
        return "https://uri.rezerve.money/api/staking/";
    }
}
