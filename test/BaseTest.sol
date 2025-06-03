// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../contracts/RebaseController.sol";
import "../contracts/Dre.sol";
import "../contracts/sDRE.sol";
import "../contracts/Treasury.sol";
import "../contracts/DreStaking.sol";
import "../contracts/mocks/MockERC20.sol";
import "../contracts/mocks/MockAggregatorV3.sol";
import "../contracts/DreAuthority.sol";
import "../contracts/DreBondDepository.sol";
import "../contracts/oracles/TokenOracleE18.sol";

contract BaseTest is Test {
    RebaseController public rebaseController;
    DRE public dre;
    sDRE public sDre;
    Treasury public treasury;
    DreStaking public staking;
    MockERC20 public mockQuoteToken;
    MockERC20 public mockQuoteToken2;
    MockERC20 public mockQuoteToken3;
    MockAggregatorV3 public dreOracle;
    MockAggregatorV3 public mockOracle;
    MockAggregatorV3 public mockOracle2;
    MockAggregatorV3 public mockOracle3;
    TokenOracleE18 public tokenOracle;
    TokenOracleE18 public tokenOracle2;
    TokenOracleE18 public tokenOracle3;
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
        mockOracle = new MockAggregatorV3(18, 1e18); // 1:1 price
        mockOracle2 = new MockAggregatorV3(18, 2e18); // 2:1 price
        mockOracle3 = new MockAggregatorV3(18, 0.5e18); // 0.5:1 price

        dreOracle = new MockAggregatorV3(18, 1e18); // 1:1 price
        tokenOracle = new TokenOracleE18(mockOracle, dreOracle, mockQuoteToken);
        tokenOracle2 = new TokenOracleE18(mockOracle2, dreOracle, mockQuoteToken2);
        tokenOracle3 = new TokenOracleE18(mockOracle3, dreOracle, mockQuoteToken3);

        // Deploy DRE token
        dre = new DRE(address(dreAuthority));

        // Deploy sDRE token
        sDre = new sDRE(address(dreAuthority));
        // Deploy Treasury
        treasury = new Treasury();
        treasury.initialize(address(dre), address(dreAuthority));
        treasury.enable(address(mockQuoteToken), address(tokenOracle));

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
        vm.label(address(mockOracle), "Mock Oracle");
        vm.label(address(mockOracle2), "Mock Oracle 2");
        vm.label(address(mockOracle3), "Mock Oracle 3");

        vm.label(address(tokenOracle), "Token Oracle");
        vm.label(address(tokenOracle2), "Token Oracle 2");
        vm.label(address(tokenOracle3), "Token Oracle 3");

        vm.stopPrank();
    }
}
