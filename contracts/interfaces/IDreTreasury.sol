// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.15;

import "./IDreAuthority.sol";
import "./IDRE.sol";

/// @title IDreTreasury
/// @notice Interface for the DRE Treasury contract that manages protocol reserves and assets
/// @dev Handles reserve management, asset deposits, and treasury operations
interface IDreTreasury {
    /* ========== EVENTS ========== */

    /// @notice Emitted when a reserve token is enabled
    /// @param token Address of the enabled token
    event ReserveTokenEnabled(address indexed token);

    /// @notice Emitted when a reserve token is disabled
    /// @param token Address of the disabled token
    event ReserveTokenDisabled(address indexed token);

    /// @notice Emitted when reserves are deposited
    /// @param token Address of the deposited token
    /// @param amount Amount deposited
    /// @param value Value in DRE
    event ReservesDeposited(address indexed token, uint256 amount, uint256 value);

    /// @notice Emitted when reserves are withdrawn
    /// @param token Address of the withdrawn token
    /// @param amount Amount withdrawn
    /// @param value Value in DRE
    event ReservesWithdrawn(address indexed token, uint256 amount, uint256 value);

    /* ========== INITIALIZATION ========== */

    /// @notice Initializes the treasury contract
    /// @param _dre Address of the DRE token contract
    /// @param _oracle Address of the oracle contract
    /// @param _authority Address of the authority contract
    function initialize(address _dre, address _oracle, address _authority) external;

    /* ========== RESERVE MANAGEMENT ========== */

    /// @notice Enables a token as a reserve
    /// @param _token Address of the token to enable
    function enable(address _token) external;

    /// @notice Disables a token as a reserve
    /// @param _token Address of the token to disable
    function disable(address _token) external;

    /// @notice Deposits reserves into the treasury
    /// @param _token Address of the token to deposit
    /// @param _amount Amount to deposit
    /// @return value_ Value of the deposit in DRE
    function deposit(address _token, uint256 _amount) external returns (uint256 value_);

    /// @notice Withdraws reserves from the treasury
    /// @param _token Address of the token to withdraw
    /// @param _amount Amount to withdraw
    /// @return value_ Value of the withdrawal in DRE
    function withdraw(address _token, uint256 _amount) external returns (uint256 value_);

    /* ========== STATE QUERIES ========== */

    /// @notice Gets the value of reserves in DRE
    /// @return uint256 Total value of reserves
    function getReserveValue() external view returns (uint256);

    /// @notice Gets the value of a specific reserve token in DRE
    /// @param _token Address of the token
    /// @return uint256 Value of the token reserves
    function getReserveValue(address _token) external view returns (uint256);

    /// @notice Checks if a token is enabled as a reserve
    /// @param _token Address of the token to check
    /// @return bool True if the token is enabled
    function isReserveToken(address _token) external view returns (bool);

    /**
     * @notice Returns the value of a token in DRE, 18 decimals
     * @param _token The address of the token
     * @param _amount The amount of the token
     * @return value_ The value of the token in DRE
     */
    function tokenValueE18(address _token, uint256 _amount) external view returns (uint256 value_);

    /// @notice Mints new DRE tokens to a recipient
    /// @param _recipient Address to receive the minted tokens
    /// @param _amount Amount of DRE to mint
    function mint(address _recipient, uint256 _amount) external;

    /// @notice Manages treasury assets by allowing authorized withdrawal of tokens
    /// @param _token Address of the token to manage
    /// @param _amount Amount of tokens to manage
    function manage(address _token, uint256 _amount) external;

    /// @notice Calculates excess reserves available in the treasury
    /// @return uint256 Amount of excess reserves in DRE
    function excessReserves() external view returns (uint256);

    /// @notice Gets the total value of all reserves in the treasury
    /// @return uint256 Total reserves value in DRE
    function totalReserves() external view returns (uint256);

    /// @notice Synchronizes the internal reserve tracking with actual balances
    function syncReserves() external;

    /// @notice Calculates the current total reserves without updating state
    /// @return uint256 Calculated reserves value in DRE
    function calculateReserves() external view returns (uint256);

    /// @notice Gets the base supply of DRE tokens
    /// @return uint256 Base supply of DRE tokens
    function baseSupply() external view returns (uint256);
}
