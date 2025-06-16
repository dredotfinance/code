// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../contracts/periphery/BlackholeLP.sol";
import "../../contracts/interfaces/IApp.sol";
import "../../contracts/interfaces/IAppTreasury.sol";
import "../../contracts/interfaces/IShadowRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BlackholeLPTest is Test {
    BlackholeLP public blackholeLP;
    IApp public appToken;
    IERC20 public quoteToken;
    IERC20 public lpToken;
    IShadowRouter public router;
    IAppTreasury public treasury;
    IAppAuthority public authority;

    // Mainnet addresses
    address public constant APP_TOKEN = 0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5;
    address public constant QUOTE_TOKEN = 0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE;
    address public constant LP_TOKEN = 0x08C5e3B7533Ee819A4d1F66e839D0E8F04ae3D0C;
    address public constant ROUTER = 0x1D368773735ee1E678950B7A97bcA2CafB330CDc;
    address public constant TREASURY = 0xe22e10f8246dF1f0845eE3E9f2F0318bd60EFC85;
    address public constant GNOSIS_SAFE = 0x0E43DF9F40Cc6eEd3eC70ea41D6F34329fE75986;
    address public constant AUTHORITY = 0x07249bd92625641f9E3DBa360967C3b18eE28AF2;

    address public constant DEPLOYER = 0x5f5a6E0F769BBb9232d2F6EDA84790296b288974;
    address public constant scUSDC_WHALE = 0xf4Fc21ee9a6114D75434BeA8C48c5c89ACC3982D;

    function setUp() public {
        uint256 mainnetFork = vm.createFork("https://rpc.soniclabs.com");
        vm.selectFork(mainnetFork);
        vm.roll(34364997);

        // Initialize contract instances
        appToken = IApp(APP_TOKEN);
        quoteToken = IERC20(QUOTE_TOKEN);
        lpToken = IERC20(LP_TOKEN);
        router = IShadowRouter(ROUTER);
        treasury = IAppTreasury(TREASURY);
        authority = IAppAuthority(AUTHORITY);

        // Deploy BlackholeLP
        vm.prank(DEPLOYER);
        blackholeLP = new BlackholeLP(APP_TOKEN, QUOTE_TOKEN, LP_TOKEN, ROUTER, TREASURY, AUTHORITY);

        vm.prank(GNOSIS_SAFE);
        authority.addPolicy(address(blackholeLP));

        vm.prank(GNOSIS_SAFE);
        authority.addExecutor(address(blackholeLP));

        // Label addresses for better debugging
        vm.label(APP_TOKEN, "RZR");
        vm.label(QUOTE_TOKEN, "USDC");
        vm.label(LP_TOKEN, "LP");
        vm.label(ROUTER, "ROUTER");
        vm.label(TREASURY, "TREASURY");
        vm.label(AUTHORITY, "AUTHORITY");
        vm.label(DEPLOYER, "DEPLOYER");
        vm.label(scUSDC_WHALE, "scUSDC_WHALE");
        vm.label(address(blackholeLP), "BLACKHOLE_LP");
    }

    function test_Purge() public {
        // Get initial balances
        console.log("Initial LP balance:", lpToken.balanceOf(TREASURY));
        console.log("Initial LP scUSDC balance:", quoteToken.balanceOf(address(lpToken)));
        console.log("Initial LP RZR balance:", appToken.balanceOf(address(lpToken)));

        // Execute purge as executor
        vm.prank(scUSDC_WHALE);
        quoteToken.transfer(address(blackholeLP), 10000e6);

        vm.prank(DEPLOYER);
        blackholeLP.purge();

        console.log("Final LP balance:", lpToken.balanceOf(TREASURY));
        console.log("Final LP scUSDC balance:", quoteToken.balanceOf(address(lpToken)));
        console.log("Final LP RZR balance:", appToken.balanceOf(address(lpToken)));
    }
}
