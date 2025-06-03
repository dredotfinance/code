// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IAggregatorV3.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DumbAggregatorOracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/IUniswapV2Pair.sol";

/**
 * @title UniV2LPOracle
 * @notice An oracle for a Uniswap V2 LP token.
 */
contract UniV2LPOracle is DumbAggregatorOracle {
    IUniswapV2Pair public amm;
    AggregatorV3Interface public token0Oracle;
    AggregatorV3Interface public token1Oracle;

    uint256 public token0Decimals;
    uint256 public token1Decimals;
    uint256 internal constant HALF_UNIT = 1e9;
    uint256 internal constant UNIT = 1e18;

    address public dre;

    constructor(address _uniV2LP, AggregatorV3Interface _token0Oracle, AggregatorV3Interface _token1Oracle) {
        amm = IUniswapV2Pair(_uniV2LP);
        token0Oracle = _token0Oracle;
        token1Oracle = _token1Oracle;

        token0Decimals = IERC20Metadata(amm.token0()).decimals();
        token1Decimals = IERC20Metadata(amm.token1()).decimals();

        require(_getPrice() > 0, "Invalid price");
    }

    function description() external pure override returns (string memory) {
        return "UniV2LPOracle";
    }

    function getKValue() public view returns (uint256 k_) {
        uint256 decimals = token0Decimals + token1Decimals - 18;
        (uint256 reserve0, uint256 reserve1,) = amm.getReserves();
        k_ = reserve0 * reserve1 / 10 ** decimals;
    }

    function _getPrice() internal view override returns (int256) {
        (uint256 r0, uint256 r1,) = amm.getReserves();
        uint256 totalSupply = amm.totalSupply();

        uint256 px0 = getPx(token0Oracle, amm.token0()); // in 1e18
        uint256 px1 = getPx(token1Oracle, amm.token1()); // in 1e8

        require(px0 > 0 && px1 > 0, "Invalid Price");

        // fair token0 amt: sqrtK * sqrt(px1/px0)
        // fair token1 amt: sqrtK * sqrt(px0/px1)
        // fair lp price = 2 * sqrt(px0 * px1)
        // split into 2 sqrts multiplication to prevent uint overflow (note the 1e18)
        uint256 sqrtK_2 = fdiv(sqrt(r0 * r1), totalSupply) * 2; // in 1e18
        // uint256 numerator = ((sqrt(px0) / TWO_56) * sqrt(px1)) / TWO_56;

        return int256((((sqrtK_2 * sqrt(px0)) / HALF_UNIT) * sqrt(px1)) / HALF_UNIT);
    }

    function markdown() external view  returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = amm.getReserves();
        uint256 reserve;
        if (amm.token0() == dre) {
            reserve = reserve1;
        } else {
            require(amm.token1() == dre, "Invalid pair");
            reserve = reserve0;
        }
        return reserve * 2 * (10 ** IERC20Metadata(dre).decimals()) / getKValue();
    }

    /// @notice Computes the square root of a given number using the Babylonian method.
    /// @dev This function uses an iterative method to compute the square root of a number.
    /// @param x The number to compute the square root of.
    /// @return y The square root of the given number.
    function sqrt(uint256 x) public pure returns (uint256 y) {
        if (x == 0) return 0; // Handle the edge case for 0
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function fdiv(uint256 lhs, uint256 rhs) internal pure returns (uint256) {
        return (lhs * UNIT) / rhs;
    }

    function getPx(AggregatorV3Interface oracle, address token) public view returns (uint256) {
        uint8 decimals = IERC20Metadata(token).decimals();
        int256 answer = oracle.latestAnswer();
        return (uint256(answer) * UNIT) / (10 ** decimals);
    }
}
