// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../contracts/RebaseController.sol";
import "../contracts/RZR.sol";
import "../contracts/sRZR.sol";
import "../contracts/AppTreasury.sol";
import "../contracts/AppStaking.sol";
import "../contracts/mocks/MockERC20.sol";
import "../contracts/mocks/MockOracle.sol";
import "../contracts/mocks/MockEndpoint.sol";
import "../contracts/AppAuthority.sol";
import "../contracts/AppBondDepository.sol";
import "../contracts/AppOracle.sol";
import "../contracts/AppBurner.sol";

contract BaseTest is Test {
    RebaseController public rebaseController;
    RZR public app;
    sRZR public sapp;
    AppTreasury public treasury;
    AppStaking public staking;
    MockERC20 public mockQuoteToken;
    MockERC20 public mockQuoteToken2;
    MockERC20 public mockQuoteToken3;

    AppOracle public appOracle;

    MockOracle public mockOracle;
    MockOracle public mockOracle2;
    MockOracle public mockOracle3;

    AppAuthority public dreAuthority;
    AppBondDepository public dreBondDepository;
    AppBurner public burner;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public operationsTreasury = makeAddr("operationsTreasury");

    function setUpBaseTest() public {
        vm.startPrank(owner);
        dreAuthority = new AppAuthority();

        // Deploy mock quote token
        mockQuoteToken = new MockERC20("Mock Token", "MTK");
        mockQuoteToken2 = new MockERC20("Mock Token 2", "MTK2");
        mockQuoteToken3 = new MockERC20("Mock Token 3", "MTK3");

        // Deploy mock oracle
        mockOracle = new MockOracle(1e18); // 1:1 price
        mockOracle2 = new MockOracle(2e18); // 2:1 price
        mockOracle3 = new MockOracle(0.5e18); // 0.5:1 price

        // Deploy RZR token
        MockEndpoint lz = new MockEndpoint();
        app = new RZR(address(lz), address(dreAuthority));

        // Deploy sRZR token
        sapp = new sRZR(address(dreAuthority));

        appOracle = new AppOracle();
        appOracle.initialize(address(dreAuthority), address(app));
        appOracle.updateOracle(address(mockQuoteToken), address(mockOracle));
        appOracle.updateOracle(address(mockQuoteToken2), address(mockOracle2));
        appOracle.updateOracle(address(mockQuoteToken3), address(mockOracle3));

        // Deploy Burner
        burner = new AppBurner();
        burner.initialize(address(appOracle), address(app), address(dreAuthority));

        // Deploy Treasury
        treasury = new AppTreasury();
        treasury.initialize(address(app), address(appOracle), address(dreAuthority));
        treasury.enable(address(mockQuoteToken));

        // Deploy Staking
        staking = new AppStaking();
        staking.initialize(address(app), address(sapp), address(dreAuthority), address(burner));

        // Deploy AppBondDepository
        dreBondDepository = new AppBondDepository();
        dreBondDepository.initialize(address(app), address(staking), address(treasury), address(dreAuthority));

        sapp.setStakingContract(address(staking));

        // Deploy RebaseController
        rebaseController = new RebaseController();
        rebaseController.initialize(
            address(app),
            address(treasury),
            address(staking),
            address(appOracle),
            address(dreAuthority),
            address(burner)
        );
        rebaseController.setTargetPcts(0.1e18, 0.15e18, 0.5e18, 0.5e18);

        dreAuthority.addPolicy(address(treasury));
        dreAuthority.addPolicy(address(rebaseController));
        dreAuthority.addPolicy(address(owner));
        dreAuthority.addPolicy(address(burner));
        dreAuthority.addExecutor(address(owner));
        dreAuthority.addBondManager(address(owner));
        dreAuthority.addExecutor(address(rebaseController));
        dreAuthority.addPolicy(address(dreBondDepository));
        dreAuthority.setOperationsTreasury(operationsTreasury);
        dreAuthority.setTreasury(address(treasury));
        dreAuthority.addReserveDepositor(address(dreBondDepository));

        vm.label(address(app), "RZR");
        vm.label(address(sapp), "sRZR");
        vm.label(address(treasury), "Treasury");
        vm.label(address(staking), "Staking");
        vm.label(address(rebaseController), "RebaseController");
        vm.label(address(dreBondDepository), "AppBondDepository");
        vm.label(address(burner), "Burner");
        vm.label(address(dreAuthority), "Authority");
        vm.label(address(mockQuoteToken), "Mock Quote Token");
        vm.label(address(mockQuoteToken2), "Mock Quote Token 2");
        vm.label(address(mockQuoteToken3), "Mock Quote Token 3");

        vm.label(address(appOracle), "RZR Oracle");
        vm.label(address(mockOracle), "Mock Oracle");
        vm.label(address(mockOracle2), "Mock Oracle 2");
        vm.label(address(mockOracle3), "Mock Oracle 3");

        vm.stopPrank();
    }
}
