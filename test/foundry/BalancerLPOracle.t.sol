// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../contracts/oracles/BalancerLPOracle.sol";
import "../../contracts/mocks/MockERC20.sol";
import "../../contracts/mocks/MockOracle.sol";
import "../../contracts/core/AppOracle.sol";
import "../../contracts/core/AppAuthority.sol";
import "../../contracts/interfaces/IOracle.sol";

contract BalancerLPOracleTest is Test {
    BalancerLPOracle public oracle;
    IOracle public spotOracle;
    IAppOracle public appOracle;

    address public constant VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;
    address public constant POOL = 0x36e6765907DD61b50Ad33F79574dD1B63339B59c;
    address public constant APP = 0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5;
    address public constant APP_ORACLE = 0x82884801428895c2550ED1CA96997BD60F74B5cC;
    address public constant SPOT_ORACLE = 0x953E6BCCCCcf01ae151A627b4C77718aC8cFaA34;
    address public constant GOVERNOR = 0x0E43DF9F40Cc6eEd3eC70ea41D6F34329fE75986;

    function setUp() public {
        uint256 mainnetFork = vm.createFork("https://rpc.soniclabs.com");
        vm.selectFork(mainnetFork);
        vm.roll(36065000);
        spotOracle = IOracle(SPOT_ORACLE);
        appOracle = IAppOracle(APP_ORACLE);

        oracle = new BalancerLPOracle(VAULT, POOL, APP, appOracle);
    }

    function _updateOracleToSpotPrice() public {
        uint256 spotPrice = spotOracle.getPrice();
        vm.startPrank(GOVERNOR);
        appOracle.setTokenPrice(spotPrice);
        vm.stopPrank();

        console.log("Spot price:", spotPrice);
    }

    function test_GetETHPx_fork_test() public {
        _updateOracleToSpotPrice();

        // Get price
        uint256 price = oracle.getPrice();

        // Basic validation - price should be non-zero
        assertTrue(price > 0, "Price should be greater than 0");

        // Log the price for debugging
        console.log("LP Token Price:", price);
        uint256 deposit = 17438742983387546259429;
        console.log("LP Token Price for deposit:", price * deposit / 1e18);
    }
}
