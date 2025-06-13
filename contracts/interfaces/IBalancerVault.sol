// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBalancerVault {
    enum BalancerTokenType {
        STANDARD,
        WITH_RATE
    }

    struct BalancerTokenInfo {
        BalancerTokenType tokenType;
        address rateProvider;
        bool paysYieldFees;
    }

    struct BalancerPoolData {
        bytes32 poolConfigBits;
        IERC20[] tokens;
        BalancerTokenInfo[] tokenInfo;
        uint256[] balancesRaw;
        uint256[] balancesLiveScaled18;
        uint256[] tokenRates;
        uint256[] decimalScalingFactors;
    }

    function getPoolData(address pool) external view returns (BalancerPoolData memory);
}

interface IBalancerPool {
    function getNormalizedWeights() external view returns (uint256[] memory);
}
