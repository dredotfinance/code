// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAppOracle.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IBalancerVault.sol";
import "../utils/BalancerMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title BalancerLPOracle
 * @notice An oracle for a Balancer LP token.
 */
contract BalancerLPOracle is BalancerMath, IOracle {
    IBalancerVault public vault;
    address public pool;

    uint256 public token0Decimals;
    uint256 public token1Decimals;
    address public app;

    IAppOracle public appOracle;

    constructor(address _vault, address _balancerLP, address _app, IAppOracle _appOracle) {
        vault = IBalancerVault(_vault);
        pool = _balancerLP;
        app = _app;
        appOracle = _appOracle;
    }

    /// @dev Return fair reserve amounts given spot reserves, weights, and fair prices.
    /// @param resA Reserve of the first asset
    /// @param resB Reserve of the second asset
    /// @param wA Weight of the first asset
    /// @param wB Weight of the second asset
    /// @param pxA Fair price of the first asset
    /// @param pxB Fair price of the second asset
    function computeFairReserves(uint256 resA, uint256 resB, uint256 wA, uint256 wB, uint256 pxA, uint256 pxB)
        internal
        pure
        returns (uint256 fairResA, uint256 fairResB)
    {
        // NOTE: wA + wB = 1 (normalize weights)
        // constant product = resA^wA * resB^wB
        // constraints:
        // - fairResA^wA * fairResB^wB = constant product
        // - fairResA * pxA / wA = fairResB * pxB / wB
        // Solving equations:
        // --> fairResA^wA * (fairResA * (pxA * wB) / (wA * pxB))^wB = constant product
        // --> fairResA / r1^wB = constant product
        // --> fairResA = resA^wA * resB^wB * r1^wB
        // --> fairResA = resA * (resB/resA)^wB * r1^wB = resA * (r1/r0)^wB

        uint256 r0 = bdiv(resA, resB);
        uint256 r1 = bdiv(bmul(wA, pxB), bmul(wB, pxA));

        // fairResA = resA * (r1 / r0) ^ wB
        // fairResB = resB * (r0 / r1) ^ wA
        if (r0 > r1) {
            uint256 ratio = bdiv(r1, r0);
            fairResA = bmul(resA, bpow(ratio, wB));
            fairResB = bdiv(resB, bpow(ratio, wA));
        } else {
            uint256 ratio = bdiv(r0, r1);
            fairResA = bdiv(resA, bpow(ratio, wB));
            fairResB = bmul(resB, bpow(ratio, wA));
        }
    }

    function getPx(address token) public view returns (uint256) {
        uint8 decimals = IERC20Metadata(token).decimals();
        uint256 answer = appOracle.getPrice(token);
        return (answer * UNIT) / (10 ** decimals);
    }

    function getPrice() public view returns (uint256) {
        IBalancerVault.BalancerPoolData memory poolData = vault.getPoolData(pool);
        require(poolData.tokens.length == 2, "num tokens must be 2");
        IERC20 tokenA = poolData.tokens[0];
        IERC20 tokenB = poolData.tokens[1];
        uint256 pxA = getPx(address(tokenA));
        uint256 pxB = getPx(address(tokenB));

        uint256[] memory weights = IBalancerPool(pool).getNormalizedWeights();

        (uint256 fairResA, uint256 fairResB) = computeFairReserves(
            poolData.balancesRaw[0],
            poolData.balancesRaw[1],
            weights[0], // poolData.tokenInfo[0].weight,
            weights[1], // poolData.tokenInfo[1].weight,
            pxA,
            pxB
        );

        // use fairReserveA and fairReserveB to compute LP token price
        // LP price = (fairResA * pxA + fairResB * pxB) / totalLPSupply
        return (fairResA * pxA + fairResB * pxB) / poolData.balancesRaw[0];
    }
}
