// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./BaseTest.sol";
import "../contracts/periphery/BootstrapLP.sol";
import "../contracts/interfaces/IDreStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DreBondDepositoryTest is BaseTest {
    BootstrapLP public bootstrapLP;

    address public constant DRE_TOKEN = 0xF8232259D4F92E44eF84F18A0B9877F4060B26F1;
    address public constant USDC_TOKEN = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
    address public constant LP_TOKEN = 0xB781C624397C423Cb62bAe9996cEbedC6734B76b;
    address public constant STAKING = 0x30902d05C499911142FE62B447dDcf19649452A3;
    address public constant sDRE_TOKEN = 0xf04947da387c2D032B496fEb14d230E5343543bf;
    address public constant ROUTER = 0x1D368773735ee1E678950B7A97bcA2CafB330CDc;
    address public constant AUTHORITY = 0xe4248e0c16B0E8D94e40bA54Ef2058CeDfe196a7;
    address public constant TREASURY = 0xb692e2706b628998B4403979D9117Ed746bf8128;

    address usdcWhale = 0xA4E471dbfe8C95d4c44f520b19CEe436c01c3267;
    address public constant DEPLOYER = 0xDC591Fc6603940AEf90Fa6B4DD0C04560B5c7E97;

    function setUp() public {
        uint256 mainnetFork = vm.createFork("https://rpc.soniclabs.com");
        vm.selectFork(mainnetFork);
        vm.roll(31429356);

        setUpBaseTest();

        vm.startPrank(DEPLOYER);
        bootstrapLP = new BootstrapLP(DRE_TOKEN, USDC_TOKEN, LP_TOKEN, STAKING, ROUTER, TREASURY, 10000000e6, 1.1e18);

        IDreAuthority(AUTHORITY).addPolicy(address(bootstrapLP));
        vm.stopPrank();

        vm.label(DRE_TOKEN, "DRE");
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

    function test_BootstrapDeposit() public {
        vm.prank(DEPLOYER);
        bootstrapLP.setBonus(1e18);

        vm.startPrank(usdcWhale);

        IERC20 usdc = IERC20(USDC_TOKEN);
        IERC20 dre = IERC20(DRE_TOKEN);
        IERC20 lp = IERC20(LP_TOKEN);
        IERC20 dreStaking = IERC20(sDRE_TOKEN);

        // Store initial balances
        uint256 initialUsdcBalance = usdc.balanceOf(usdcWhale);
        uint256 initialDreBalance = dre.balanceOf(usdcWhale);
        uint256 initialDreTotalSupply = dre.totalSupply();
        uint256 initialDreLpBalance = dre.balanceOf(LP_TOKEN);
        uint256 initialUsdcLpBalance = usdc.balanceOf(LP_TOKEN);
        uint256 initialLpTreasuryBalance = lp.balanceOf(TREASURY);
        uint256 initialStakedBalance = dreStaking.balanceOf(usdcWhale);

        usdc.approve(address(bootstrapLP), type(uint256).max);
        bootstrapLP.bootstrap(1000000e6);

        // Verify USDC balance decreased by the bootstrap amount
        assertEq(
            usdc.balanceOf(usdcWhale),
            initialUsdcBalance - 1000000e6,
            "USDC balance should decrease by bootstrap amount"
        );

        // Verify DRE total supply increased
        assertGt(dre.totalSupply(), initialDreTotalSupply, "DRE total supply should increase");

        // Verify LP tokens were sent to treasury
        assertGt(lp.balanceOf(TREASURY), initialLpTreasuryBalance, "LP tokens should be sent to treasury");

        // Verify staked balance increased
        assertGt(dreStaking.balanceOf(usdcWhale), initialStakedBalance, "Staked balance should increase");

        // Verify LP token has DRE and USDC balances
        assertGt(dre.balanceOf(LP_TOKEN), initialDreLpBalance, "LP should have more DRE tokens");
        assertGt(usdc.balanceOf(LP_TOKEN), initialUsdcLpBalance, "LP should have more USDC tokens");
    }

    function test_BootstrapDepositWithBonus() public {
        vm.prank(DEPLOYER);
        bootstrapLP.setBonus(1.05e18);

        vm.startPrank(usdcWhale);

        IERC20 usdc = IERC20(USDC_TOKEN);
        IERC20 dre = IERC20(DRE_TOKEN);
        IERC20 lp = IERC20(LP_TOKEN);
        IERC20 dreStaking = IERC20(sDRE_TOKEN);

        usdc.approve(address(bootstrapLP), type(uint256).max);
        bootstrapLP.bootstrap(10000e6);
    }

    function test_BootstrapDepositAfterSwap() public {
        IERC20 usdc = IERC20(USDC_TOKEN);
        IERC20 dre = IERC20(DRE_TOKEN);
        IERC20 lp = IERC20(LP_TOKEN);
        IERC20 dreStaking = IERC20(sDRE_TOKEN);

        vm.startPrank(usdcWhale);

        console.log("DRE balance of whale", dre.balanceOf(usdcWhale));
        console.log("DRE balance of LP", dre.balanceOf(LP_TOKEN));
        console.log("USDC balance of whale", usdc.balanceOf(usdcWhale));
        console.log("USDC balance of LP", usdc.balanceOf(LP_TOKEN));
        console.log("LP balance of Treasury", lp.balanceOf(TREASURY));
        console.log("Staked balance of whale", dreStaking.balanceOf(usdcWhale));
        console.log("Staked balance of LP", dreStaking.balanceOf(LP_TOKEN));

        // Do a swap to shift the price of DRE
        usdc.approve(address(ROUTER), type(uint256).max);
        IShadowRouter router = IShadowRouter(ROUTER);
        IShadowRouter.route[] memory routes = new IShadowRouter.route[](1);
        routes[0] = IShadowRouter.route({from: USDC_TOKEN, to: DRE_TOKEN, stable: false});
        router.swapExactTokensForTokens(1000e6, 0, routes, address(bootstrapLP), block.timestamp);

        console.log("--------------------------------");
        console.log("DRE balance of whale", dre.balanceOf(usdcWhale));
        console.log("DRE balance of LP", dre.balanceOf(LP_TOKEN));
        console.log("USDC balance of whale", usdc.balanceOf(usdcWhale));
        console.log("USDC balance of LP", usdc.balanceOf(LP_TOKEN));
        console.log("LP balance of Treasury", lp.balanceOf(TREASURY));
        console.log("Staked balance of whale", dreStaking.balanceOf(usdcWhale));
        console.log("Staked balance of LP", dreStaking.balanceOf(LP_TOKEN));

        // Bootstrap with the same amount of USDC
        usdc.approve(address(bootstrapLP), type(uint256).max);
        bootstrapLP.bootstrap(1000000e6);

        console.log("--------------------------------");

        console.log("DRE balance of whale", dre.balanceOf(usdcWhale));
        console.log("DRE balance of LP", dre.balanceOf(LP_TOKEN));
        console.log("USDC balance of whale", usdc.balanceOf(usdcWhale));
        console.log("USDC balance of LP", usdc.balanceOf(LP_TOKEN));
        console.log("LP balance of Treasury", lp.balanceOf(TREASURY));
        console.log("Staked balance of whale", dreStaking.balanceOf(usdcWhale));
        console.log("Staked balance of LP", dreStaking.balanceOf(LP_TOKEN));
    }
}

// 502003 USDC
// 125636 DRE

// 1 DRE = 502003 / 125636 = 3.99570202732240437158469924812031 USDCp
