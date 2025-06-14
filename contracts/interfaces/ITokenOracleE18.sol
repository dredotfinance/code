// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ITokenOracleE18 {
    function tokenDecimals() external view returns (uint256);
    function tokenOracleDecimals() external view returns (uint256);

    function priceInAppE18() external view returns (int256 value, uint256 updatedAt);
    function priceInAppE18ForAmount(uint256 _amount) external view returns (int256 value, uint256 updatedAt);
}
