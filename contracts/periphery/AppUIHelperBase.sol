// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import "../interfaces/IAppStaking.sol";
import "../interfaces/IAppBondDepository.sol";
import "../interfaces/IRebaseController.sol";
import "../interfaces/IAppTreasury.sol";
import "../interfaces/IAppOracle.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IBootstrapLP.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title RZR UI Helper
/// @author RZR Protocol
abstract contract AppUIHelperBase {
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

    struct ProjectedEpochRate {
        uint256 apr;
        uint256 epochRate;
        uint256 toStakers;
        uint256 toOps;
        uint256 toBurner;
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
        address _appToken,
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
        appToken = IERC20(_appToken);
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
}
