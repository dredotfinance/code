// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../contracts/oracles/TokenOracleE18.sol";
import "../contracts/mocks/MockAggregatorV3.sol";
import "../contracts/mocks/MockERC20.sol";

contract TokenOracleE18Test is Test {
    TokenOracleE18 public tokenOracle;

    MockAggregatorV3 public token6DecOracle;
    MockAggregatorV3 public dreOracle;

    MockERC20 public token6Dec;
    MockERC20 public dre;

    function setUp() public {
        // Create mock token with 18 decimals
        token6Dec = new MockERC20("USDC", "USDC");
        token6Dec.setDecimals(6);

        dre = new MockERC20("DRE", "DRE");
        dre.setDecimals(18);

        token6DecOracle = new MockAggregatorV3(8, 1e8);
        dreOracle = new MockAggregatorV3(18, 1e18);
    }

    function test_PriceConversion6Decimals() public {
        // Create new token with 6 decimals
        TokenOracleE18 token6Oracle = new TokenOracleE18(token6DecOracle, dreOracle, token6Dec);

        (int256 value, uint256 updatedAt) = token6Oracle.priceInDreE18();
        assertEq(value, 1e18, "priceInDreE18() -> Price should be 1e18");
        assertEq(updatedAt, block.timestamp, "updatedAt should be the current block timestamp");

        (value, updatedAt) = token6Oracle.priceInDreE18ForAmount(1e6);
        assertEq(value, 1e18, "priceInDreE18ForAmount(1e6) -> Price should be 1e18");
        assertEq(updatedAt, block.timestamp, "updatedAt should be the current block timestamp");

        dreOracle.setPrice(2e18);
        (value, updatedAt) = token6Oracle.priceInDreE18();
        assertEq(value, 0.5e18, "priceInDreE18ForAmount(1e6) -> Price should be 0.5e18");
        assertEq(updatedAt, block.timestamp, "updatedAt should be the current block timestamp");
    }

    function test_PriceConversionDreOracle() public {
        // Create new token with 6 decimals
        TokenOracleE18 oracle = new TokenOracleE18(dreOracle, dreOracle, dre);

        (int256 value, uint256 updatedAt) = oracle.priceInDreE18();
        assertEq(value, 1e18, "priceInDreE18() -> Price should be 1e18");
        assertEq(updatedAt, block.timestamp, "updatedAt should be the current block timestamp");

        (value, updatedAt) = oracle.priceInDreE18ForAmount(1e18);
        assertEq(value, 1e18, "priceInDreE18ForAmount(1e18) -> Price should be 1e18");
        assertEq(updatedAt, block.timestamp, "updatedAt should be the current block timestamp");

        dreOracle.setPrice(2e18);
        (value, updatedAt) = oracle.priceInDreE18();
        assertEq(value, 1e18, "priceInDreE18() -> Price should be 1e18 as DRE/DRE is 1");
        assertEq(updatedAt, block.timestamp, "updatedAt should be the current block timestamp");
    }

    function test_PriceConversion18Decimals() public {
        // Create new token with 18 decimals
        token6Dec.setDecimals(18);
        TokenOracleE18 oracle = new TokenOracleE18(token6DecOracle, dreOracle, token6Dec);

        (int256 value, uint256 updatedAt) = oracle.priceInDreE18();
        assertEq(value, 1e18, "priceInDreE18() -> Price should be 1e18");
        assertEq(updatedAt, block.timestamp, "updatedAt should be the current block timestamp");

        (value, updatedAt) = oracle.priceInDreE18ForAmount(1e18);
        assertEq(value, 1e18, "priceInDreE18ForAmount(1e18) -> Price should be 1e18");
        assertEq(updatedAt, block.timestamp, "updatedAt should be the current block timestamp");
    }

    function test_PriceConversion18DecimalsWith6DecimalsOracle() public {
        // Create new token with 18 decimals
        token6Dec.setDecimals(18);
        token6DecOracle.setDecimals(18);
        token6DecOracle.setPrice(1e18);
        TokenOracleE18 oracle = new TokenOracleE18(token6DecOracle, dreOracle, token6Dec);

        (int256 value, uint256 updatedAt) = oracle.priceInDreE18();
        assertEq(value, 1e18, "priceInDreE18() -> Price should be 1e18");
        assertEq(updatedAt, block.timestamp, "updatedAt should be the current block timestamp");

        (value, updatedAt) = oracle.priceInDreE18ForAmount(1e20);
        assertEq(value, 1e20, "priceInDreE18ForAmount(1e18) -> Price should be 1e18");
        assertEq(updatedAt, block.timestamp, "updatedAt should be the current block timestamp");
    }
}
