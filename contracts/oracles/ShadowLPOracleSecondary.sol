// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IOracle.sol";
import "../interfaces/IAppOracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IShadowLP {
    function current(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/**
 * @title ShadowLPOracleSecondary
 * @notice This contract fetches the price from a shadow LP pair secondary to the base token
 * @dev Do not use this by any means use this contract directly in any onchain code. Use it only for frontend
 * @dev Price is returned in 18 decimals
 */
contract ShadowLPOracleSecondary is IOracle {
    IShadowLP public amm;
    IAppOracle public appOracle;
    uint256 public decimalOffset;
    IERC20Metadata public quoteToken;
    IERC20Metadata public baseToken;

    constructor(IShadowLP _amm, address _baseToken, address _appOracle) {
        amm = _amm;
        appOracle = IAppOracle(_appOracle);
        baseToken = IERC20Metadata(_baseToken);
        quoteToken = IERC20Metadata(amm.token0() == _baseToken ? amm.token1() : amm.token0());

        decimalOffset = 10 ** (18 - quoteToken.decimals());
    }

    /**
     * @notice Returns the price of the token in the shadow LP pair
     * @return price The price of the token in the shadow LP pair
     */
    function getPrice() external view override returns (uint256) {
        return amm.current(address(baseToken), 1e18) * decimalOffset * appOracle.getPrice(address(quoteToken)) / 1e18;
    }
}
