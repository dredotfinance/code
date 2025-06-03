// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../contracts/RebaseController.sol";
import "../contracts/Dre.sol";
import "../contracts/sDRE.sol";
import "../contracts/DreTreasury.sol";
import "../contracts/DreStaking.sol";
import "../contracts/mocks/MockERC20.sol";
import "../contracts/mocks/MockOracle.sol";
import "../contracts/DreAuthority.sol";
import "../contracts/DreBondDepository.sol";
import "../contracts/oracles/TokenOracleE18.sol";
import "../contracts/DreOracle.sol";
import "../contracts/mocks/MockEndpoint.sol";

contract BaseTest is Test {
    RebaseController public rebaseController;
    DRE public dre;
    sDRE public sDre;
    DreTreasury public treasury;
    DreStaking public staking;
    MockERC20 public mockQuoteToken;
    MockERC20 public mockQuoteToken2;
    MockERC20 public mockQuoteToken3;

    DreOracle public dreOracle;

    MockOracle public mockDreOracle;
    MockOracle public mockOracle;
    MockOracle public mockOracle2;
    MockOracle public mockOracle3;

    DreAuthority public dreAuthority;
    DreBondDepository public dreBondDepository;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public operationsTreasury = makeAddr("operationsTreasury");

    function setUpBaseTest() public {
        vm.startPrank(owner);
        dreAuthority = new DreAuthority();

        // Deploy mock quote token
        mockQuoteToken = new MockERC20("Mock Token", "MTK");
        mockQuoteToken2 = new MockERC20("Mock Token 2", "MTK2");
        mockQuoteToken3 = new MockERC20("Mock Token 3", "MTK3");

        // Deploy mock oracle
        mockDreOracle = new MockOracle(1e18); // 1:1 price
        mockOracle = new MockOracle(1e18); // 1:1 price
        mockOracle2 = new MockOracle(2e18); // 2:1 price
        mockOracle3 = new MockOracle(0.5e18); // 0.5:1 price

        // Deploy DRE token
        MockLayerZero lz = new MockLayerZero();
        dre = new DRE(address(lz), address(dreAuthority));

        // Deploy sDRE token
        sDre = new sDRE(address(dreAuthority));

        dreOracle = new DreOracle();
        dreOracle.initialize(address(dreAuthority), address(dre));
        dreOracle.updateOracle(address(dre), address(mockDreOracle));
        dreOracle.updateOracle(address(mockQuoteToken), address(mockOracle));
        dreOracle.updateOracle(address(mockQuoteToken2), address(mockOracle2));
        dreOracle.updateOracle(address(mockQuoteToken3), address(mockOracle3));

        // Deploy Treasury
        treasury = new DreTreasury();
        treasury.initialize(address(dre), address(dreOracle), address(dreAuthority));
        treasury.enable(address(mockQuoteToken));

        // Deploy Staking
        staking = new DreStaking();
        staking.initialize(address(dre), address(sDre), address(dreAuthority));

        // Deploy DreBondDepository
        dreBondDepository = new DreBondDepository();
        dreBondDepository.initialize(address(dre), address(staking), address(treasury), address(dreAuthority));

        sDre.setStakingContract(address(staking));

        // Deploy RebaseController
        rebaseController = new RebaseController();
        rebaseController.initialize(address(dre), address(treasury), address(staking), address(dreAuthority));

        dreAuthority.addPolicy(address(treasury));
        dreAuthority.addPolicy(address(rebaseController));
        dreAuthority.addPolicy(address(dreBondDepository));
        dreAuthority.setOperationsTreasury(operationsTreasury);
        dreAuthority.setTreasury(address(treasury));
        dreAuthority.addReserveDepositor(address(dreBondDepository));

        vm.label(address(dre), "DRE");
        vm.label(address(sDre), "sDRE");
        vm.label(address(treasury), "Treasury");
        vm.label(address(staking), "Staking");
        vm.label(address(rebaseController), "RebaseController");
        vm.label(address(dreBondDepository), "DreBondDepository");
        vm.label(address(mockQuoteToken), "Mock Quote Token");
        vm.label(address(mockQuoteToken2), "Mock Quote Token 2");
        vm.label(address(mockQuoteToken3), "Mock Quote Token 3");

        vm.label(address(dreOracle), "Dre Oracle");
        vm.label(address(mockDreOracle), "Mock Dre Oracle");
        vm.label(address(mockOracle), "Mock Oracle");
        vm.label(address(mockOracle2), "Mock Oracle 2");
        vm.label(address(mockOracle3), "Mock Oracle 3");

        vm.stopPrank();
    }
}
