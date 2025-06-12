// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IAppOracle {
    event OracleUpdated(address indexed token, address indexed oracle);

    // Errors
    error OracleNotFound(address token);
    error OracleAlreadyExists(address token);
    error OracleInactive(address token);
    error InvalidOracleAddress();
    error InvalidTokenAddress();

    /// @notice Initializes the AppOracle contract
    /// @dev This function is only callable once
    /// @param _authority The address of the authority contract
    /// @param _dre The address of the dre contract
    function initialize(address _authority, address _dre) external;

    /**
     * @notice Update the oracle for a token
     * @param token The token address
     * @param oracle The oracle contract
     */
    function updateOracle(address token, address oracle) external;

    /**
     * @notice Get the price for a token
     * @param token The token address
     * @return price The token price
     */
    function getPrice(address token) external view returns (uint256);

    /**
     * @notice Get the price for a token in RZR
     * @param token The token address
     * @return price The token price in RZR
     */
    function getPriceInApp(address token) external view returns (uint256 price);

    /**
     * @notice Get the price for a token in RZR for an amount
     * @param token The token address
     * @param amount The amount of the token
     * @return price The token price in RZR for the amount
     */
    function getPriceInAppForAmount(address token, uint256 amount) external view returns (uint256 price);

    /**
     * @notice Get the price for RZR
     * @return price The RZR price
     */
    function getAppPrice() external view returns (uint256);

    /**
     * @notice Set the price for RZR
     * @param newFloorPrice The new RZR price
     */
    function setAppPrice(uint256 newFloorPrice) external;

    /**
     * @notice Get the price for a token for an amount
     * @param token The token address
     * @param amount The amount of the token
     * @return price The token price for the amount
     */
    function getPriceForAmount(address token, uint256 amount) external view returns (uint256);
}
