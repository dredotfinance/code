// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.15;
pragma abicoder v2;

import "./IApp.sol";
import "./IAppStaking.sol";
import "./IAppTreasury.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/// @title IAppBondDepository
/// @notice Interface for managing bond depository operations, including bond creation, deposits, claims, and staking
/// @dev This interface extends IERC721Enumerable to provide NFT functionality for bond positions
interface IAppBondDepository is IERC721Enumerable {
    /* ======== EVENTS ======== */
    /// @notice Emitted when a new bond is created
    /// @param id The unique identifier of the bond
    /// @param quoteToken The address of the token used for payment
    /// @param initialPrice The starting price of the bond
    /// @param capacity The maximum capacity of the bond
    event CreateBond(uint256 indexed id, address indexed quoteToken, uint256 initialPrice, uint256 capacity);

    /// @notice Emitted when a bond is closed
    /// @param id The unique identifier of the bond
    event CloseBond(uint256 indexed id);

    /// @notice Emitted when a bond position is created
    /// @param id The unique identifier of the bond
    /// @param amount The amount of tokens in the bond
    /// @param price The price at which the bond was created
    event BondCreated(uint256 indexed id, uint256 amount, uint256 price);

    /// @notice Emitted when tokens are claimed from a bond position
    /// @param id The unique identifier of the bond position
    /// @param amount The amount of tokens claimed
    event Claimed(uint256 indexed id, uint256 amount);

    /// @notice Emitted when a bond position is staked
    /// @param id The unique identifier of the bond position
    /// @param amount The amount of tokens staked
    event Staked(uint256 indexed id, uint256 amount);

    /// @notice Emitted when a bond is disabled
    /// @param id The unique identifier of the bond
    event DisableBond(uint256 indexed id);

    /* ======== STRUCTS ======== */
    /// @notice Represents a bond offering
    /// @param enabled Whether the bond is currently enabled
    /// @param capacity The remaining capacity of the bond
    /// @param quoteToken The token accepted as payment
    /// @param totalDebt The total debt from the bond
    /// @param maxPayout The maximum tokens that can be paid out
    /// @param sold The amount of RZR tokens sold
    /// @param purchased The amount of quote tokens received
    /// @param startTime The timestamp when the bond starts
    /// @param endTime The timestamp when the bond ends
    /// @param initialPrice The starting price in quote token
    /// @param finalPrice The ending price in quote token
    struct Bond {
        bool enabled;
        uint256 capacity; // capacity remaining
        IERC20 quoteToken; // token to accept as payment
        uint256 totalDebt; // total debt from bond
        uint256 maxPayout; // max tokens in/out
        uint256 sold; // RZR tokens out
        uint256 purchased; // quote tokens in
        uint256 startTime; // when the bond starts
        uint256 endTime; // when the bond ends
        uint256 initialPrice; // starting price in quote token
        uint256 finalPrice; // ending price in quote token
    }

    /// @notice Represents a user's bond position
    /// @param bondId The ID of the associated bond
    /// @param amount The amount of RZR tokens in the position
    /// @param quoteAmount The amount of quote tokens paid
    /// @param startTime The timestamp when the position was created
    /// @param lastClaimTime The timestamp of the last claim
    /// @param claimedAmount The amount of tokens already claimed
    /// @param isStaked Whether the position is currently staked
    struct BondPosition {
        uint256 bondId;
        uint256 amount; // amount of RZR tokens
        uint256 quoteAmount; // amount of quote tokens paid
        uint256 startTime; // when the bond was purchased
        uint256 lastClaimTime; // last time tokens were claimed
        uint256 claimedAmount; // amount of tokens already claimed
        bool isStaked; // whether the position is staked
    }

    /* ======== FUNCTIONS ======== */
    /// @notice Initializes the bond depository contract
    /// @param _dre The address of the RZR token
    /// @param _staking The address of the staking contract
    /// @param _treasury The address of the treasury contract
    /// @param _authority The address of the authority contract
    function initialize(address _dre, address _staking, address _treasury, address _authority) external;

    /// @notice Creates a new bond offering
    /// @param _quoteToken The token to accept as payment
    /// @param _capacity The maximum capacity of the bond
    /// @param _initialPrice The starting price of the bond
    /// @param _finalPrice The ending price of the bond
    /// @param _duration The duration of the bond in seconds
    /// @return id_ The unique identifier of the created bond
    function create(
        IERC20 _quoteToken,
        uint256 _capacity,
        uint256 _initialPrice,
        uint256 _finalPrice,
        uint256 _duration
    ) external returns (uint256 id_);

    /// @notice Deposits quote tokens to purchase a bond
    /// @param _id The ID of the bond to purchase
    /// @param _amount The amount of quote tokens to deposit
    /// @param _maxPrice The maximum price willing to pay
    /// @param _minPayout The minimum payout expected
    /// @param _user The address of the user making the deposit
    /// @return payout_ The amount of RZR tokens received
    /// @return tokenId_ The ID of the created bond position NFT
    function deposit(uint256 _id, uint256 _amount, uint256 _maxPrice, uint256 _minPayout, address _user)
        external
        returns (uint256 payout_, uint256 tokenId_);

    /// @notice Claims vested tokens from a bond position
    /// @param _tokenId The ID of the bond position NFT
    function claim(uint256 _tokenId) external;

    /// @notice Stakes a bond position
    /// @param _tokenId The ID of the bond position NFT
    /// @param _declaredValue The declared value for staking
    function stake(uint256 _tokenId, uint256 _declaredValue) external;

    /// @notice Checks if a bond is currently live
    /// @param _id The ID of the bond to check
    /// @return bool True if the bond is live, false otherwise
    function isLive(uint256 _id) external view returns (bool);

    /// @notice Gets the current price of a bond
    /// @param _id The ID of the bond
    /// @return uint256 The current price of the bond
    function currentPrice(uint256 _id) external view returns (uint256);

    /// @notice Gets the amount of tokens claimable from a bond position
    /// @param _tokenId The ID of the bond position NFT
    /// @return uint256 The amount of tokens that can be claimed
    function claimableAmount(uint256 _tokenId) external view returns (uint256);

    /// @notice Gets the details of a bond
    /// @param _id The ID of the bond
    /// @return Bond The bond details
    function getBond(uint256 _id) external view returns (Bond memory);

    /// @notice Gets the total number of bonds
    /// @return uint256 The number of bonds
    function bondLength() external view returns (uint256);

    /// @notice Gets a bond by its index
    /// @param index The index of the bond
    /// @return bond The bond details
    function bonds(uint256 index) external view returns (Bond memory bond);

    /// @notice Gets a bond position by its token ID
    /// @param tokenId The ID of the bond position NFT
    /// @return position The bond position details
    function positions(uint256 tokenId) external view returns (BondPosition memory position);

    /// @notice Gets the vesting period for bonds
    /// @return uint256 The vesting period in seconds
    function VESTING_PERIOD() external view returns (uint256);

    /// @notice Gets the staking lock period
    /// @return uint256 The staking lock period in seconds
    function STAKING_LOCK_PERIOD() external view returns (uint256);

    /// @notice Gets the basis points used for calculations
    /// @return uint256 The basis points value
    function BASIS_POINTS() external view returns (uint256);

    /// @notice Gets the team share percentage
    /// @return uint256 The team share percentage
    function TEAM_SHARE() external view returns (uint256);

    /// @notice Gets the staking contract address
    /// @return IAppStaking The staking contract interface
    function staking() external view returns (IAppStaking);

    /// @notice Gets the main app contract address
    /// @return IApp The app contract interface
    function app() external view returns (IApp);

    /// @notice Gets the treasury contract address
    /// @return IAppTreasury The treasury contract interface
    function treasury() external view returns (IAppTreasury);

    /// @notice Gets the last used bond ID
    /// @return uint256 The last used bond ID
    function lastId() external view returns (uint256);
}
