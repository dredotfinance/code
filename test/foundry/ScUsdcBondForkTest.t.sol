// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAppTreasury} from "../../contracts/interfaces/IAppTreasury.sol";
import {IAppBondDepository} from "../../contracts/interfaces/IAppBondDepository.sol";
import {IAppAuthority} from "../../contracts/interfaces/IAppAuthority.sol";

contract ScUsdcBondForkTest is Test {
    // Fork test for scUSDC bond creation
    // Using parameters from the create-scusdc.ts script
    // Fork configuration
    uint256 public constant SONIC_BLOCK = 36308065;
    string public constant SONIC_RPC = "https://rpc.soniclabs.com";

    // scUSDC token address on ===
    address public constant SC_USDC = 0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE;

    // Bond parameters from the script
    uint256 public constant BOND_CAPACITY = 100 ether; // 100 RZR
    uint256 public constant INITIAL_PRICE = 3469018;
    uint256 public constant FINAL_PRICE = 3083572;
    uint256 public constant BOND_DURATION = 7 days; // 7 days in seconds

    IAppTreasury public treasury = IAppTreasury(0xe22e10f8246dF1f0845eE3E9f2F0318bd60EFC85);
    IAppBondDepository public bondDepository = IAppBondDepository(0x44b497aa4b742dc48Ce0bd26F66da9aecA19Bd75);
    IAppAuthority public authority = IAppAuthority(0x07249bd92625641f9E3DBa360967C3b18eE28AF2);
    address public owner = 0x5f5a6E0F769BBb9232d2F6EDA84790296b288974;
    IERC20 public scUSDC = IERC20(SC_USDC);

    address whale = makeAddr("whale");

    function test_CreateScUsdcBond_fork_test() public {
        vm.createSelectFork(SONIC_RPC, SONIC_BLOCK);
        vm.startPrank(owner);

        // Create bond with the exact parameters from the script
        uint256 bondId = bondDepository.create(scUSDC, BOND_CAPACITY, INITIAL_PRICE, FINAL_PRICE, BOND_DURATION);

        // Verify bond was created successfully
        IAppBondDepository.Bond memory bond = bondDepository.getBond(bondId);

        assertEq(bond.capacity, BOND_CAPACITY);
        assertEq(address(bond.quoteToken), SC_USDC);
        assertEq(bond.totalDebt, 0);
        assertEq(bond.maxPayout, BOND_CAPACITY);
        assertEq(bond.sold, 0);
        assertEq(bond.purchased, 0);
        assertEq(bond.initialPrice, INITIAL_PRICE);
        assertEq(bond.finalPrice, FINAL_PRICE);
        assertEq(bond.endTime, bond.startTime + BOND_DURATION);

        console.log("Bond created successfully with ID:", bondId);
        console.log("Bond capacity:", bond.capacity);
        console.log("Quote token:", address(bond.quoteToken));
        console.log("Initial price:", bond.initialPrice);
        console.log("Final price:", bond.finalPrice);
        console.log("Duration:", BOND_DURATION);
        console.log("Start time:", bond.startTime);
        console.log("End time:", bond.endTime);

        deal(address(scUSDC), whale, 1000 ether);
        vm.startPrank(whale);
        scUSDC.approve(address(bondDepository), type(uint256).max);

        // uint256 _id, uint256 _amount, uint256 _maxPrice, uint256 _minPayout, address _user
        bondDepository.deposit(bondId, 1000 * 1e6, type(uint256).max, 0, whale);

        require(false, "test");
        vm.stopPrank();
    }
}
