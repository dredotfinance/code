// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./DreAccessControlled.sol";
import "./interfaces/IDreOracle.sol";
import "./interfaces/IOracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title OracleRepository
 * @notice Central repository for managing token oracles
 * @dev Allows adding, updating, and removing oracles for different tokens
 */
contract DreOracle is DreAccessControlled, IDreOracle {
    mapping(IERC20Metadata => IOracle) public oracles;
    IERC20Metadata public dre;

    function initialize(address _authority, address _dre) external initializer {
        __DreAccessControlled_init(_authority);
        dre = IERC20Metadata(_dre);
    }

    /**
     * @notice Add a new oracle for a token
     * @param token The token address
     * @param oracle The oracle contract
     */
    function updateOracle(IERC20Metadata token, IOracle oracle) external onlyGovernor {
        if (address(token) == address(0)) revert InvalidTokenAddress();
        if (address(oracle) == address(0)) revert InvalidOracleAddress();

        oracles[token] = oracle;
        require(getPriceInDre(token) > 0, "Invalid price");
        require(token.decimals() > 0 && token.totalSupply() > 0, "Invalid token");

        emit OracleUpdated(address(token), address(oracle));
    }

    /**
     * @notice Get the price for a token
     * @param token The token address
     * @return price The token price
     */
    function getPrice(IERC20Metadata token) public view returns (uint256 price) {
        IOracle oracle = oracles[token];
        if (address(oracle) == address(0)) revert OracleNotFound(address(token));
        price = oracle.getPrice();
    }

    /**
     * @notice Get the price for a token in DRE
     * @param token The token address
     * @return price The token price in DRE
     */
    function getPriceInDre(IERC20Metadata token) public view returns (uint256 price) {
        IOracle tokenOracle = oracles[token];
        IOracle dreOracle = oracles[dre];

        uint256 tokenPrice = tokenOracle.getPrice(); // USDC/USD
        require(tokenPrice > 0, "Invalid price");
        uint256 tokenPriceE18 = tokenPrice * 10 ** (18 - token.decimals()); // USDC/USD in E18

        uint256 drePriceE18 = dreOracle.getPrice(); // DRE/USD
        require(drePriceE18 > 0, "Invalid price");

        uint256 amountE18 = price * 10 ** (18 - token.decimals()); // amount in E18
        price = (tokenPriceE18 * amountE18) / drePriceE18;
    }

    /**
     * @notice Get the price for a token in DRE for an amount
     * @param token The token address
     * @param amount The amount of the token
     * @return price The token price in DRE for the amount
     */
    function getPriceInDreForAmount(address token, uint256 amount) external view returns (uint256 price) {
        IERC20Metadata tokenMetadata = IERC20Metadata(token);

        uint256 tokenAmountE18 = amount * 10 ** (18 - tokenMetadata.decimals()); // amount in E18
        uint256 tokenPrice = getPrice(tokenMetadata); // TOKEN/USD
        uint256 drePriceE18 = dreOracle.getPrice(); // DRE/USD

        price = (tokenPrice * tokenAmountE18) / drePriceE18;
    }

    /**
     * @notice Get the price for a token for an amount
     * @param token The token address
     * @param amount The amount of the token
     * @return price The token price for the amount
     */
    function getPriceForAmount(address token, uint256 amount) external view returns (uint256 price) {
        IERC20Metadata tokenMetadata = IERC20Metadata(token);
        uint256 tokenAmountE18 = amount * 10 ** (18 - tokenMetadata.decimals()); // amount in E18
        uint256 tokenPrice = getPrice(tokenMetadata); // TOKEN/USD
        price = (tokenPrice * tokenAmountE18) / 1e18;
    }
}
