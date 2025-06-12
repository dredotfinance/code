// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./AppAccessControlled.sol";
import "./interfaces/IAppOracle.sol";
import "./interfaces/IOracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title OracleRepository
 * @notice Central repository for managing token oracles
 * @dev Allows adding, updating, and removing oracles for different tokens
 */
contract AppOracle is IAppOracle, AppAccessControlled {
    mapping(IERC20Metadata => IOracle) public oracles;
    IERC20Metadata public app;
    uint256 private _floorPrice; // in USD with 18 decimals

    event FloorPriceUpdated(uint256 oldPrice, uint256 newPrice);

    /// @inheritdoc IAppOracle
    function initialize(address _authority, address _dre) external initializer {
        __AppAccessControlled_init(_authority);
        app = IERC20Metadata(_dre);
        require(app.decimals() == 18, "RZR must have 18 decimals");
        if (_floorPrice == 0) _floorPrice = 1e18; // Start at 1 USD
    }

    /// @inheritdoc IAppOracle
    function updateOracle(address token, address oracle) external onlyGovernor {
        if (address(token) == address(0)) revert InvalidTokenAddress();
        if (address(oracle) == address(0)) revert InvalidOracleAddress();

        oracles[IERC20Metadata(token)] = IOracle(oracle);
        require(getPriceInToken(address(token)) >= 0, "Invalid price");
        require(IERC20Metadata(token).decimals() > 0, "Invalid token");

        emit OracleUpdated(address(token), address(oracle));
    }

    /// @inheritdoc IAppOracle
    function getPrice(address token) public view returns (uint256 price) {
        if (token == address(app)) return _floorPrice;
        IOracle oracle = oracles[IERC20Metadata(token)];
        if (address(oracle) == address(0)) revert OracleNotFound(address(token));
        price = oracle.getPrice();
    }

    /// @inheritdoc IAppOracle
    function getPriceInToken(address token) public view returns (uint256 price) {
        uint256 tokenPriceE18 = getPrice(token); // TOKEN/USD in E18
        price = (tokenPriceE18 * 1e18) / _floorPrice;
    }

    /// @inheritdoc IAppOracle
    function getPriceInTokenForAmount(address token, uint256 amount) external view returns (uint256 price) {
        IERC20Metadata tokenMetadata = IERC20Metadata(token);

        uint256 tokenAmountE18 = amount * 10 ** (18 - tokenMetadata.decimals()); // amount in E18
        uint256 tokenPriceE18 = getPrice(token); // TOKEN/USD
        uint256 drePriceE18 = _floorPrice; // RZR/USD

        price = (tokenPriceE18 * tokenAmountE18) / drePriceE18;
    }

    /// @inheritdoc IAppOracle
    function getPriceForAmount(address token, uint256 amount) external view returns (uint256 price) {
        IERC20Metadata tokenMetadata = IERC20Metadata(token);
        uint256 tokenAmountE18 = amount * 10 ** (18 - tokenMetadata.decimals()); // amount in E18
        uint256 tokenPriceE18 = getPrice(token); // TOKEN/USD
        price = (tokenPriceE18 * tokenAmountE18) / 1e18;
    }

    /// @inheritdoc IAppOracle
    function getTokenPrice() external view returns (uint256) {
        return _floorPrice;
    }

    /// @inheritdoc IAppOracle
    function setTokenPrice(uint256 newFloorPrice) external onlyPolicy {
        require(newFloorPrice >= _floorPrice, "floor price can only increase");

        uint256 oldPrice = _floorPrice;
        _floorPrice = newFloorPrice;

        emit FloorPriceUpdated(oldPrice, newFloorPrice);
    }
}
