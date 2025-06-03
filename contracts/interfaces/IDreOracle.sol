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

    function getPrice() external view returns (uint256);

    function getPriceInDre(IERC20Metadata token) external view returns (uint256 price);

    function getPriceInDreForAmount(IERC20Metadata token, uint256 amount) external view returns (uint256 price);
}
