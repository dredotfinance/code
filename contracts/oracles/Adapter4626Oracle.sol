// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IOracle.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Adapter4626Oracle is IOracle {
    IERC4626 public immutable VAULT;

    constructor(IERC4626 _vault) {
        VAULT = _vault;
    }

    function getPrice() external view override returns (uint256) {
        return VAULT.convertToAssets(1 ether);
    }
}
