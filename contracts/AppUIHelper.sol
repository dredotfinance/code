// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.15;
pragma abicoder v2;

import "./interfaces/IAppStaking.sol";
import "./interfaces/IAppBondDepository.sol";
import "./interfaces/IRebaseController.sol";
import "./interfaces/IAppTreasury.sol";
import "./interfaces/IAppOracle.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IBootstrapLP.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title RZR UI Helper
/// @author RZR Protocol
contract AppUIHelper {
    using SafeERC20 for IERC20;

    struct TokenInfo {
        address token;
        string name;
        string symbol;
        uint256 balance;
        uint256 allowance;
        uint256 treasuryBalance;
        uint256 treasuryValueApp;
        uint8 decimals;
        uint256 oraclePrice;
        uint256 oraclePriceInApp;
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
        uint256 amount; // amount of RZR tokens
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
        uint256 sold; // RZR tokens out
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
    IAppStaking public staking;
    IAppBondDepository public bondDepository;
    IAppTreasury public treasury;
    IERC20 public appToken;
    IERC20 public stakingToken;
    IAppOracle public appOracle;
    IRebaseController public rebaseController;
    IOracle public shadowLP;
    IBootstrapLP public bootstrapLP;
    address public odos;

    // Events
    event RewardsClaimed(uint256 indexed positionId, uint256 amount);

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
    ) {
        staking = IAppStaking(_staking);
        bondDepository = IAppBondDepository(_bondDepository);
        treasury = IAppTreasury(_treasury);
        appToken = IERC20(_dreToken);
        stakingToken = IERC20(_stakingToken);
        appOracle = IAppOracle(_appOracle);
        shadowLP = IOracle(_shadowLP);
        rebaseController = IRebaseController(_rebaseController);
        bootstrapLP = IBootstrapLP(_bootstrapLP);
        odos = _odos;

        IERC20 usdcToken = bootstrapLP.usdcToken();
        usdcToken.approve(address(bootstrapLP), type(uint256).max);
        appToken.approve(address(staking), type(uint256).max);
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
            uint256 currentSpotPrice,
            TokenInfo[] memory tokenInfos,
            StakingPositionInfo[] memory stakingPositions,
            BondPositionInfo[] memory bondPositions
        )
    {
        // Get protocol-wide stats
        tvl = treasury.calculateReserves();
        totalSupply = appToken.totalSupply();
        totalStaked = staking.totalStaked();
        totalRewards = staking.rewardPerToken();
        currentAPR = calculateAPRRaw(totalStaked);
        currentSpotPrice = shadowLP.getPrice();

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
            oraclePriceInApp: appOracle.getTokenPrice()
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

        (bool success,) = odos.call{value: tokenAmountIn}(odosData);
        require(success, "Odos call failed");

        dreAmountSwapped = appToken.balanceOf(address(this));
        staking.createPosition(to, dreAmountSwapped, dreAmountDeclared, 0);
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

        (bool success,) = odos.call{value: tokenAmountIn}(odosData);
        require(success, "Odos call failed");

        dreAmountSwapped = appToken.balanceOf(address(this));
        uint256 dreAmountDeclared = (dreAmountSwapped * dreAmountDeclaredAsPercentage) / 1e18;
        staking.createPosition(to, dreAmountSwapped, dreAmountDeclared, 0);
    }
}
