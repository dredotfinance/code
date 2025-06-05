// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IDreOracle {
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

    /**
     * @notice Get the price for DRE
     * @return price The DRE price
     */
    function getDrePrice() external view returns (uint256);

    /**
     * @notice Set the price for DRE
     * @param newFloorPrice The new DRE price
     */
    function setDrePrice(uint256 newFloorPrice) external;
}
