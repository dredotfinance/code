// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IAggregatorV3.sol";
import "../interfaces/ITokenOracleE18.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract TokenOracleE18 is ITokenOracleE18 {
    AggregatorV3Interface public tokenOracle;
    AggregatorV3Interface public dreOracle;
    IERC20Metadata public token;

    uint256 public tokenDecimals;
    uint256 public tokenOracleDecimals;

    constructor(AggregatorV3Interface _tokenOracle, AggregatorV3Interface _dreOracle, IERC20 _token) {
        tokenOracle = _tokenOracle;
        dreOracle = _dreOracle;
        token = IERC20Metadata(address(_token));

        tokenDecimals = uint256(uint8(token.decimals()));
        tokenOracleDecimals = uint256(uint8(tokenOracle.decimals()));

        require(dreOracle.decimals() == 18, "DRE oracle must have 18 decimals");
    }

    function tokenValueE18(uint256 _amount) public view returns (int256 value, uint256 updatedAt) {
        (, int256 price,, uint256 tokenUpdatedAt,) = tokenOracle.latestRoundData(); // USDC/USD
        require(price > 0, "Invalid price");
        uint256 priceE18 = uint256(price) * 10 ** (18 - tokenOracleDecimals); // USDC/USD in E18

        (, int256 drePriceE18,, uint256 dreUpdatedAt,) = dreOracle.latestRoundData(); // DRE/USD
        require(drePriceE18 > 0, "Invalid price");

        uint256 amountE18 = uint256(_amount) * 10 ** (18 - tokenDecimals); // amount in E18
        value = int256(uint256(priceE18) * amountE18 / uint256(drePriceE18));
        updatedAt = Math.min(tokenUpdatedAt, dreUpdatedAt);
    }

    function priceInDreE18() external view override returns (int256 value, uint256 updatedAt) {
        return tokenValueE18(10 ** tokenDecimals);
    }

    function priceInDreE18ForAmount(uint256 _amount) external view override returns (int256 value, uint256 updatedAt) {
        return tokenValueE18(_amount);
    }
}
