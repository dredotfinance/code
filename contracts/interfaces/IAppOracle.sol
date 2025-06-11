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
     * @notice Get the price for a token in App
     * @param token The token address
     * @return price The token price in App
     */
    function getPriceInApp(address token) external view returns (uint256 price);

    /**
     * @notice Get the price for a token in App for an amount
     * @param token The token address
     * @param amount The amount of the token
     * @return price The token price in App for the amount
     */
    function getPriceInAppForAmount(address token, uint256 amount) external view returns (uint256 price);

    /**
     * @notice Get the price for App
     * @return price The App price
     */
    function getAppPrice() external view returns (uint256);

    /**
     * @notice Set the price for App
     * @param newFloorPrice The new App price
     */
    function setAppPrice(uint256 newFloorPrice) external;
}
