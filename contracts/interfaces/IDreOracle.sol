// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title IDreOracle
/// @notice Interface for the DRE Oracle contract that manages price feeds and floor price
/// @dev Handles price updates and provides price information for the DRE token
interface IDreOracle {
    /* ========== EVENTS ========== */

    /// @notice Emitted when the DRE price is updated
    /// @param newPrice The new DRE price
    /// @param oldPrice The old DRE price
    event PriceUpdated(uint256 newPrice, uint256 oldPrice);

    /// @notice Emitted when a new oracle is added
    /// @param token The token address
    /// @param oracle The oracle address
    event OracleAdded(address token, address oracle);

    /// @notice Emitted when an oracle is removed
    /// @param token The token address
    /// @param oracle The oracle address
    event OracleRemoved(address token, address oracle);

    /* ========== INITIALIZATION ========== */

    /// @notice Initializes the oracle contract
    /// @param _authority Address of the authority contract
    /// @param _dre Address of the DRE token contract
    function initialize(address _authority, address _dre) external;

    /* ========== ORACLE MANAGEMENT ========== */

    /// @notice Updates or adds a new oracle for a token
    /// @param token Address of the token
    /// @param oracle Address of the oracle contract
    function updateOracle(address token, address oracle) external;

    /// @notice Removes an oracle for a token
    /// @param token Address of the token
    function removeOracle(address token) external;

    /* ========== PRICE MANAGEMENT ========== */

    /// @notice Sets the DRE floor price
    /// @param _price The new floor price
    function setDrePrice(uint256 _price) external;

    /// @notice Gets the current DRE floor price
    /// @return uint256 The current floor price
    function getDrePrice() external view returns (uint256);

    /// @notice Gets the price of a token from its oracle
    /// @param token Address of the token
    /// @return uint256 The token price
    function getTokenPrice(address token) external view returns (uint256);

    /// @notice Gets the price of a token pair
    /// @param token0 First token address
    /// @param token1 Second token address
    /// @return uint256 The price of token0 in terms of token1
    function getTokenPairPrice(address token0, address token1) external view returns (uint256);

    // Errors
    error OracleNotFound(address token);
    error OracleAlreadyExists(address token);
    error OracleInactive(address token);
    error InvalidOracleAddress();
    error InvalidTokenAddress();

    /**
     * @notice Get the price for a token
     * @param token The token address
     * @return price The token price
     */
    function getPrice(address token) external view returns (uint256);

    /**
     * @notice Get the price for a token in DRE
     * @param token The token address
     * @return price The token price in DRE
     */
    function getPriceInDre(address token) external view returns (uint256 price);

    /**
     * @notice Get the price for a token in DRE for an amount
     * @param token The token address
     * @param amount The amount of the token
     * @return price The token price in DRE for the amount
     */
    function getPriceInDreForAmount(address token, uint256 amount) external view returns (uint256 price);
}
