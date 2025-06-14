// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/oracles/BalancerLPOracle.sol";
import "../contracts/mocks/MockERC20.sol";
import "../contracts/mocks/MockOracle.sol";
import "../contracts/core/AppOracle.sol";
import "../contracts/core/AppAuthority.sol";

contract BalancerLPOracleTest is Test {
    BalancerLPOracle public oracle;

    address public constant VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;
    address public constant POOL = 0x36e6765907DD61b50Ad33F79574dD1B63339B59c;
    address public constant APP = 0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5;
    address public constant APP_ORACLE = 0x82884801428895c2550ED1CA96997BD60F74B5cC;

    function setUp() public {
        uint256 mainnetFork = vm.createFork("https://rpc.soniclabs.com");
        vm.selectFork(mainnetFork);
        vm.roll(33800435);

        oracle = new BalancerLPOracle(VAULT, POOL, APP, IAppOracle(APP_ORACLE));
    }

    function testGetETHPx() public view {
        // Get price
        uint256 price = oracle.getPrice();

        // Basic validation - price should be non-zero
        assertTrue(price > 0, "Price should be greater than 0");

        // Log the price for debugging
        console.log("LP Token Price:", price);
        uint256 deposit = 11369988147785217165412;
        console.log("LP Token Price for deposit:", price * deposit / 1e18);
    }
}
