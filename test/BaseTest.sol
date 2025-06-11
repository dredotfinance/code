// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../contracts/RebaseController.sol";
import "../contracts/App.sol";
import "../contracts/sApp.sol";
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
    App public app;
    sApp public sapp;
    AppTreasury public treasury;
    AppStaking public staking;
    MockERC20 public mockQuoteToken;
    MockERC20 public mockQuoteToken2;
    MockERC20 public mockQuoteToken3;

    AppOracle public dreOracle;

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

        // Deploy App token
        MockEndpoint lz = new MockEndpoint();
        app = new App(address(lz), address(dreAuthority));

        // Deploy sApp token
        sapp = new sApp(address(dreAuthority));

        dreOracle = new AppOracle();
        dreOracle.initialize(address(dreAuthority), address(app));
        dreOracle.updateOracle(address(mockQuoteToken), address(mockOracle));
        dreOracle.updateOracle(address(mockQuoteToken2), address(mockOracle2));
        dreOracle.updateOracle(address(mockQuoteToken3), address(mockOracle3));

        // Deploy Burner
        burner = new AppBurner();
        burner.initialize(address(dreOracle), address(app), address(dreAuthority));

        // Deploy Treasury
        treasury = new AppTreasury();
        treasury.initialize(address(app), address(dreOracle), address(dreAuthority));
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
            address(dreOracle),
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

        vm.label(address(app), "App");
        vm.label(address(sapp), "sApp");
        vm.label(address(treasury), "Treasury");
        vm.label(address(staking), "Staking");
        vm.label(address(rebaseController), "RebaseController");
        vm.label(address(dreBondDepository), "AppBondDepository");
        vm.label(address(burner), "Burner");
        vm.label(address(dreAuthority), "Authority");
        vm.label(address(mockQuoteToken), "Mock Quote Token");
        vm.label(address(mockQuoteToken2), "Mock Quote Token 2");
        vm.label(address(mockQuoteToken3), "Mock Quote Token 3");

        vm.label(address(dreOracle), "App Oracle");
        vm.label(address(mockOracle), "Mock Oracle");
        vm.label(address(mockOracle2), "Mock Oracle 2");
        vm.label(address(mockOracle3), "Mock Oracle 3");

        vm.stopPrank();
    }
}
