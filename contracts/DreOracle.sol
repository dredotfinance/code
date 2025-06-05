// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./DreAccessControlled.sol";
import "./interfaces/IDreOracle.sol";
import "./interfaces/IOracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title OracleRepository
 * @notice Central repository for managing token oracles
 * @dev Allows adding, updating, and removing oracles for different tokens
 */
contract DreOracle is IDreOracle, DreAccessControlled {
    mapping(IERC20Metadata => IOracle) public oracles;
    IERC20Metadata public dre;
    uint256 private _floorPrice; // in USD with 18 decimals

    event FloorPriceUpdated(uint256 oldPrice, uint256 newPrice);

    function initialize(address _authority, address _dre) external initializer {
        __DreAccessControlled_init(_authority);
        dre = IERC20Metadata(_dre);
        require(dre.decimals() == 18, "DRE must have 18 decimals");
        if (_floorPrice == 0) _floorPrice = 1e18; // Start at 1 USD
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
        if (token == address(dre)) return _floorPrice;
        IOracle oracle = oracles[IERC20Metadata(token)];
        if (address(oracle) == address(0)) revert OracleNotFound(address(token));
        price = oracle.getPrice();
    }

    /// @inheritdoc IDreOracle
    function getPriceInDre(address token) public view returns (uint256 price) {
        uint256 tokenPriceE18 = getPrice(token); // TOKEN/USD in E18
        price = (tokenPriceE18 * 1e18) / _floorPrice;
    }

    /// @inheritdoc IDreOracle
    function getPriceInDreForAmount(address token, uint256 amount) external view returns (uint256 price) {
        IERC20Metadata tokenMetadata = IERC20Metadata(token);

        uint256 tokenAmountE18 = amount * 10 ** (18 - tokenMetadata.decimals()); // amount in E18
        uint256 tokenPriceE18 = getPrice(token); // TOKEN/USD
        uint256 drePriceE18 = _floorPrice; // DRE/USD

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

    function getDrePrice() external view returns (uint256) {
        return _floorPrice;
    }

    function setDrePrice(uint256 newFloorPrice) external onlyPolicy {
        require(newFloorPrice >= _floorPrice, "floor price can only increase");

        uint256 oldPrice = _floorPrice;
        _floorPrice = newFloorPrice;

        emit FloorPriceUpdated(oldPrice, newFloorPrice);
    }
}
