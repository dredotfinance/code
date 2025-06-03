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
        require(dre.decimals() == 18, "DRE must have 18 decimals");
    }

    /// @inheritdoc IDreOracle
    function updateOracle(address token, address oracle) external onlyGovernor {
        if (address(token) == address(0)) revert InvalidTokenAddress();
        if (address(oracle) == address(0)) revert InvalidOracleAddress();

        oracles[IERC20Metadata(token)] = IOracle(oracle);
        require(getPriceInDre(address(token)) >= 0, "Invalid price");
        require(IERC20Metadata(token).decimals() > 0, "Invalid token");

        emit OracleUpdated(address(token), address(oracle));
    }

    /// @inheritdoc IDreOracle
    function getPrice(address token) public view returns (uint256 price) {
        IOracle oracle = oracles[IERC20Metadata(token)];
        if (address(oracle) == address(0)) revert OracleNotFound(address(token));
        price = oracle.getPrice();
    }

    /// @inheritdoc IDreOracle
    function getPriceInDre(address token) public view returns (uint256 price) {
        uint256 tokenPriceE18 = getPrice(token); // TOKEN/USD in E18
        uint256 drePriceE18 = getPrice(address(dre)); // DRE/USD
        price = (tokenPriceE18 * 1e18) / drePriceE18;
    }

    /// @inheritdoc IDreOracle
    function getPriceInDreForAmount(address token, uint256 amount) external view returns (uint256 price) {
        IERC20Metadata tokenMetadata = IERC20Metadata(token);

        uint256 tokenAmountE18 = amount * 10 ** (18 - tokenMetadata.decimals()); // amount in E18
        uint256 tokenPriceE18 = getPrice(token); // TOKEN/USD
        uint256 drePriceE18 = getPrice(address(dre)); // DRE/USD

        price = (tokenPriceE18 * tokenAmountE18) / drePriceE18;
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
        uint256 tokenPriceE18 = getPrice(token); // TOKEN/USD
        price = (tokenPriceE18 * tokenAmountE18) / 1e18;
    }
}
