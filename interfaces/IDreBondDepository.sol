// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.15;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IDreStaking.sol";
import "./ITreasury.sol";

interface IDreBondDepository {
    /* ======== EVENTS ======== */
    event CreateBond(uint256 indexed id, address indexed quoteToken, uint256 initialPrice, uint256 capacity);
    event CloseBond(uint256 indexed id);
    event BondCreated(uint256 indexed id, uint256 amount, uint256 price);
    event Claimed(uint256 indexed id, uint256 amount);
    event Staked(uint256 indexed id, uint256 amount);

    /* ======== STRUCTS ======== */
    struct Bond {
        uint256 capacity; // capacity remaining
        IERC20 quoteToken; // token to accept as payment
        bool capacityInQuote; // capacity limit is in payment token (true) or in DRE (false)
        uint256 totalDebt; // total debt from bond
        uint256 maxPayout; // max tokens in/out
        uint256 sold; // DRE tokens out
        uint256 purchased; // quote tokens in
        uint256 startTime; // when the bond starts
        uint256 endTime; // when the bond ends
        uint256 initialPrice; // starting price in quote token
        uint256 finalPrice; // ending price in quote token
    }

    struct BondPosition {
        uint256 bondId;
        uint256 amount; // amount of DRE tokens
        uint256 quoteAmount; // amount of quote tokens paid
        uint256 startTime; // when the bond was purchased
        uint256 lastClaimTime; // last time tokens were claimed
        uint256 claimedAmount; // amount of tokens already claimed
        bool isStaked; // whether the position is staked
    }

    /* ======== FUNCTIONS ======== */
    function initialize(address _dre, address _staking, address _treasury, address _authority) external;

    function create(
        IERC20 _quoteToken,
        uint256 _capacity,
        uint256 _initialPrice,
        uint256 _finalPrice,
        uint256 _duration
    ) external returns (uint256 id_);

    function deposit(
        uint256 _id,
        uint256 _amount,
        uint256 _maxPrice,
        uint256 _minPayout,
        address _user
    ) external returns (uint256 payout_, uint256 tokenId_);

    function claim(uint256 _tokenId) external;

    function stake(uint256 _tokenId, uint256 _declaredValue) external;

    function isLive(uint256 _id) external view returns (bool);

    function currentPrice(uint256 _id) external view returns (uint256);

    function claimableAmount(uint256 _tokenId) external view returns (uint256);

    function getBond(uint256 _id) external view returns (Bond memory);

    function bondLength() external view returns (uint256);

    function bonds(
        uint256
    )
        external
        view
        returns (
            uint256 capacity,
            IERC20 quoteToken,
            bool capacityInQuote,
            uint256 totalDebt,
            uint256 maxPayout,
            uint256 sold,
            uint256 purchased,
            uint256 startTime,
            uint256 endTime,
            uint256 initialPrice,
            uint256 finalPrice
        );

    function positions(
        uint256
    )
        external
        view
        returns (
            uint256 bondId,
            uint256 amount,
            uint256 quoteAmount,
            uint256 startTime,
            uint256 lastClaimTime,
            uint256 claimedAmount,
            bool isStaked
        );

    function VESTING_PERIOD() external view returns (uint256);
    function STAKING_LOCK_PERIOD() external view returns (uint256);
    function BASIS_POINTS() external view returns (uint256);
    function TEAM_SHARE() external view returns (uint256);
    function staking() external view returns (IDreStaking);
    function dre() external view returns (IERC20);
    function treasury() external view returns (ITreasury);
    function lastId() external view returns (uint256);
}
