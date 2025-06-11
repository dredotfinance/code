// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./BaseTest.sol";
import "../contracts/periphery/BootstrapLP.sol";
import "../contracts/interfaces/IAppStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BootstrapLPTest is BaseTest {
    BootstrapLP public bootstrapLP;

    address public constant DRE_TOKEN = 0xd4eee4c318794bA6FFA7816A850a166FFf8310a9;
    address public constant USDC_TOKEN = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
    address public constant LP_TOKEN = 0x18b6963ebe82B87c338032649aAaD4Eec43D3Ecb;
    address public constant STAKING = 0x21Cfa934CEa191fBD874ee8B1B6CE2B2224De653;
    address public constant sDRE_TOKEN = 0x11E7D11F63fCeEd28CB3f06eB4C94b3e9F30890f;
    address public constant ROUTER = 0x1D368773735ee1E678950B7A97bcA2CafB330CDc;
    address public constant AUTHORITY = 0xe4248e0c16B0E8D94e40bA54Ef2058CeDfe196a7;
    address public constant TREASURY = 0xc589858dA047A4789e099FA2CfD1D974D14F344B;

    address usdcWhale = 0xA4E471dbfe8C95d4c44f520b19CEe436c01c3267;
    address public constant DEPLOYER = 0xDC591Fc6603940AEf90Fa6B4DD0C04560B5c7E97;

    function setUp() public {
        uint256 mainnetFork = vm.createFork("https://rpc.soniclabs.com");
        vm.selectFork(mainnetFork);
        vm.roll(31673783);

        setUpBaseTest();

        vm.startPrank(DEPLOYER);
        bootstrapLP = new BootstrapLP(DRE_TOKEN, USDC_TOKEN, LP_TOKEN, STAKING, ROUTER, TREASURY, 10000000e6, 1.1e18, 0);

        IAppAuthority(AUTHORITY).addPolicy(address(bootstrapLP));
        vm.stopPrank();

        // dreOracle.setAppPrice(1e18);

        vm.label(DRE_TOKEN, "RZR");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(LP_TOKEN, "LP");
        vm.label(STAKING, "STAKING");
        vm.label(ROUTER, "ROUTER");
        vm.label(AUTHORITY, "AUTHORITY");
        vm.label(TREASURY, "TREASURY");
        vm.label(DEPLOYER, "DEPLOYER");
        vm.label(usdcWhale, "usdcWhale");
        vm.label(address(bootstrapLP), "bootstrapLP");
    }

    // function test_BootstrapDeposit_only() public {
    //     vm.prank(DEPLOYER);
    //     bootstrapLP.setBonus(1e18);

    //     vm.startPrank(usdcWhale);

    //     IERC20 usdc = IERC20(USDC_TOKEN);
    //     IERC20 app = IERC20(DRE_TOKEN);
    //     IERC20 lp = IERC20(LP_TOKEN);
    //     IERC20 dreStaking = IERC20(sDRE_TOKEN);

    //     // Store initial balances
    //     uint256 initialUsdcBalance = usdc.balanceOf(usdcWhale);
    //     // uint256 initialAppBalance = app.balanceOf(usdcWhale);
    //     uint256 initialAppTotalSupply = app.totalSupply();
    //     uint256 initialAppLpBalance = app.balanceOf(LP_TOKEN);
    //     uint256 initialUsdcLpBalance = usdc.balanceOf(LP_TOKEN);
    //     uint256 initialLpTreasuryBalance = lp.balanceOf(TREASURY);
    //     uint256 initialStakedBalance = dreStaking.balanceOf(usdcWhale);

    //     usdc.approve(address(bootstrapLP), type(uint256).max);
    //     bootstrapLP.bootstrap(1000000e6);

    //     // Verify USDC balance decreased by the bootstrap amount
    //     assertApproxEqRel(
    //         usdc.balanceOf(usdcWhale),
    //         initialUsdcBalance - 1000000e6,
    //         1e18,
    //         "USDC balance should decrease by bootstrap amount"
    //     );

    //     // Verify RZR total supply increased
    //     assertGt(app.totalSupply(), initialAppTotalSupply, "RZR total supply should increase");

    //     // Verify LP tokens were sent to treasury
    //     assertGt(lp.balanceOf(TREASURY), initialLpTreasuryBalance, "LP tokens should be sent to treasury");

    //     // Verify staked balance increased
    //     assertGt(dreStaking.balanceOf(usdcWhale), initialStakedBalance, "Staked balance should increase");

    //     // Verify LP token has RZR and USDC balances
    //     assertGt(app.balanceOf(LP_TOKEN), initialAppLpBalance, "LP should have more RZR tokens");
    //     assertGt(usdc.balanceOf(LP_TOKEN), initialUsdcLpBalance, "LP should have more USDC tokens");
    // }

    // function test_BootstrapDepositWithBonus() public {
    //     vm.prank(DEPLOYER);
    //     bootstrapLP.setBonus(1.05e18);

    //     vm.startPrank(usdcWhale);

    //     IERC20 usdc = IERC20(USDC_TOKEN);
    //     usdc.approve(address(bootstrapLP), type(uint256).max);
    //     bootstrapLP.bootstrap(10000e6);
    // }

    // function test_BootstrapDepositAfterSwap() public {
    //     IERC20 usdc = IERC20(USDC_TOKEN);

    //     vm.startPrank(usdcWhale);

    //     // Do a swap to shift the price of RZR
    //     usdc.approve(address(ROUTER), type(uint256).max);
    //     IShadowRouter router = IShadowRouter(ROUTER);
    //     IShadowRouter.route[] memory routes = new IShadowRouter.route[](1);
    //     routes[0] = IShadowRouter.route({from: USDC_TOKEN, to: DRE_TOKEN, stable: false});
    //     router.swapExactTokensForTokens(1000e6, 0, routes, address(bootstrapLP), block.timestamp);

    //     // Bootstrap with the same amount of USDC
    //     usdc.approve(address(bootstrapLP), type(uint256).max);
    //     bootstrapLP.bootstrap(1000000e6);
    // }
}
