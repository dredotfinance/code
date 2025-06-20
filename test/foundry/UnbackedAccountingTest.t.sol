// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/periphery/UnbackedAccounting.sol";

contract UnbackedAccountingTest is BaseTest {
    UnbackedAccounting public unbackedAccounting;

    function setUp() public {
        setUpBaseTest();
        vm.startPrank(owner);

        // Deploy UnbackedAccounting
        unbackedAccounting = new UnbackedAccounting(address(app), address(treasury), address(authority));

        // Add roles to owner
        authority.addGovernor(owner);
        authority.addExecutor(owner);
        authority.addPolicy(address(unbackedAccounting));
    }

    function test_InitialState() public view {
        assertEq(address(unbackedAccounting.rzrToken()), address(app));
        assertEq(address(unbackedAccounting.treasury()), address(treasury));
        assertEq(address(unbackedAccounting.authority()), address(authority));
        assertEq(unbackedAccounting.totalOutflow(), 0);
        assertEq(unbackedAccounting.totalUnbackedSupply(), 0);
        assertEq(unbackedAccounting.getMonitoredContracts().length, 0);
    }

    function test_AddMonitoredContract() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        // Mint RZR to the test contract (less than unbacked supply)
        app.mint(testContract, 750e18);

        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);

        UnbackedAccounting.MonitoredContract[] memory contracts = unbackedAccounting.getMonitoredContracts();
        assertEq(contracts.length, 1);
        assertEq(contracts[0].contractAddress, testContract, "Contract address mismatch");
        assertEq(contracts[0].unbackedSupply, unbackedSupply, "Unbacked supply mismatch");
        assertEq(contracts[0].outflow, 250e18, "Outflow mismatch"); // 1000 - 750 = 250 tokens left
        assertEq(unbackedAccounting.totalUnbackedSupply(), unbackedSupply, "Total unbacked supply mismatch");
        assertEq(unbackedAccounting.getNetUnbackedSupply(), 750e18, "Net unbacked supply mismatch"); // 1000 - 250 = 750
    }

    function test_AddMonitoredContract_UpdateExisting() public {
        address testContract = address(0x123);
        uint256 initialUnbackedSupply = 1000e18;
        uint256 updatedUnbackedSupply = 2000e18;

        // Mint RZR to the test contract
        app.mint(testContract, 750e18);

        // Add contract initially
        unbackedAccounting.addMonitoredContract(testContract, initialUnbackedSupply);
        assertEq(unbackedAccounting.totalUnbackedSupply(), initialUnbackedSupply, "Total unbacked supply mismatch");
        assertEq(unbackedAccounting.totalOutflow(), 250e18, "Total outflow mismatch");
        assertEq(unbackedAccounting.getNetUnbackedSupply(), 750e18, "Net unbacked supply mismatch");

        // Update the same contract
        unbackedAccounting.addMonitoredContract(testContract, updatedUnbackedSupply);

        UnbackedAccounting.MonitoredContract[] memory contracts = unbackedAccounting.getMonitoredContracts();
        assertEq(contracts.length, 1);
        assertEq(contracts[0].unbackedSupply, updatedUnbackedSupply, "Unbacked supply mismatch");
        assertEq(unbackedAccounting.totalUnbackedSupply(), updatedUnbackedSupply, "Total unbacked supply mismatch");
        assertEq(unbackedAccounting.totalOutflow(), 1250e18, "Total outflow mismatch");
        assertEq(unbackedAccounting.getNetUnbackedSupply(), 750e18, "Net unbacked supply mismatch"); // 2000 - 750 = 1250
    }

    function test_RemoveMonitoredContract() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);
        assertEq(unbackedAccounting.getMonitoredContracts().length, 1);

        unbackedAccounting.removeMonitoredContract(testContract);
        assertEq(unbackedAccounting.getMonitoredContracts().length, 0);
        assertEq(unbackedAccounting.totalUnbackedSupply(), 0);
    }

    function test_Update_WithBalanceTracking() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        // Add contract to monitoring
        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);

        // Mint RZR to the test contract (less than unbacked supply)
        app.mint(testContract, 600e18);

        // Update to calculate outflows
        unbackedAccounting.update();

        // Check that outflow is calculated correctly (unbacked supply - balance)
        UnbackedAccounting.MonitoredContract[] memory contracts = unbackedAccounting.getMonitoredContracts();
        assertEq(contracts[0].outflow, 400e18); // 1000 - 600 = 400 tokens left
        assertEq(unbackedAccounting.totalOutflow(), 400e18);
        assertEq(unbackedAccounting.getNetUnbackedSupply(), 600e18); // 1000 - 400 = 600
    }

    function test_Update_WithMultipleContracts() public {
        address contract1 = address(0x123);
        address contract2 = address(0x456);
        uint256 unbackedSupply1 = 1000e18;
        uint256 unbackedSupply2 = 2000e18;

        // Add contracts to monitoring
        unbackedAccounting.addMonitoredContract(contract1, unbackedSupply1);
        unbackedAccounting.addMonitoredContract(contract2, unbackedSupply2);

        // Mint RZR to contracts (less than their unbacked supply)
        app.mint(contract1, 600e18); // 400 outflow (1000 - 600)
        app.mint(contract2, 1500e18); // 500 outflow (2000 - 1500)

        // Update to calculate outflows
        unbackedAccounting.update();

        // Check totals
        assertEq(unbackedAccounting.totalOutflow(), 900e18); // 400 + 500
        assertEq(unbackedAccounting.totalUnbackedSupply(), 3000e18); // 1000 + 2000
        assertEq(unbackedAccounting.getNetUnbackedSupply(), 2100e18); // 3000 - 900 = 2100
    }

    function test_Update_WithZeroBalance() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        // Add contract to monitoring
        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);

        // Don't mint any RZR to the contract (balance = 0)

        // Update to calculate outflows
        unbackedAccounting.update();

        // Check that outflow equals unbacked supply when balance is 0
        UnbackedAccounting.MonitoredContract[] memory contracts = unbackedAccounting.getMonitoredContracts();
        assertEq(contracts[0].outflow, 1000e18); // All tokens have left (1000 - 0)
        assertEq(unbackedAccounting.totalOutflow(), 1000e18);
        assertEq(unbackedAccounting.getNetUnbackedSupply(), 0); // 1000 - 1000 = 0
    }

    function test_Update_WithBalanceEqualToUnbackedSupply() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        // Add contract to monitoring
        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);

        // Mint exactly the unbacked supply amount
        app.mint(testContract, 1000e18);

        // Update to calculate outflows
        unbackedAccounting.update();

        // Check that outflow is 0 when balance equals unbacked supply
        UnbackedAccounting.MonitoredContract[] memory contracts = unbackedAccounting.getMonitoredContracts();
        assertEq(contracts[0].outflow, 0); // No tokens have left
        assertEq(unbackedAccounting.totalOutflow(), 0);
        assertEq(unbackedAccounting.getNetUnbackedSupply(), 1000e18); // 1000 - 0 = 1000
    }

    function test_Update_WithBalanceGreaterThanUnbackedSupply() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        // Add contract to monitoring
        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);

        // Mint more than the unbacked supply amount
        app.mint(testContract, 1500e18);

        // Update to calculate outflows
        unbackedAccounting.update();

        // Check that outflow is 0 when balance is greater than unbacked supply
        UnbackedAccounting.MonitoredContract[] memory contracts = unbackedAccounting.getMonitoredContracts();
        assertEq(contracts[0].outflow, 0); // No tokens have left (balance > unbacked supply)
        assertEq(unbackedAccounting.totalOutflow(), 0);
        assertEq(unbackedAccounting.getNetUnbackedSupply(), 1000e18); // 1000 - 0 = 1000
    }

    function test_Update_UpdatesTreasuryUnbackedSupply() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        // Add contract to monitoring
        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);

        // Mint RZR to the test contract (less than unbacked supply)
        app.mint(testContract, 600e18);

        // Get initial treasury unbacked supply
        uint256 initialTreasuryUnbacked = treasury.unbackedSupply();

        // Update to calculate outflows and update treasury
        unbackedAccounting.update();

        // Check that treasury unbacked supply was updated
        uint256 expectedNetUnbacked = 600e18; // 1000 - 400 = 600
        assertEq(treasury.unbackedSupply(), expectedNetUnbacked);
    }

    function test_CalculateUnbackedSupply() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        // Add contract to monitoring
        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);

        // Mint RZR to the test contract (less than unbacked supply)
        app.mint(testContract, 500e18);

        // Calculate unbacked supply without updating state
        (uint256 totalOutflow, uint256 totalUnbackedSupply, uint256 netUnbackedSupply) =
            unbackedAccounting.calculateUnbackedSupply();

        assertEq(totalOutflow, 500e18, "Total outflow mismatch"); // 1000 - 500 = 500
        assertEq(totalUnbackedSupply, 1000e18, "Total unbacked supply mismatch");
        assertEq(netUnbackedSupply, 500e18, "Net unbacked supply mismatch"); // 1000 - 500 = 500
    }

    function test_GetTotalOutflow() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);
        app.mint(testContract, 500e18);
        unbackedAccounting.update();

        assertEq(unbackedAccounting.totalOutflow(), 500e18); // 1000 - 500 = 500
    }

    function test_GetTotalUnbackedSupply() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);
        unbackedAccounting.update();

        assertEq(unbackedAccounting.totalUnbackedSupply(), 1000e18);
    }

    function test_GetNetUnbackedSupply() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);
        app.mint(testContract, 500e18);
        unbackedAccounting.update();

        assertEq(unbackedAccounting.getNetUnbackedSupply(), 500e18); // 1000 - 500 = 500
    }

    function test_AccessControl_AddMonitoredContract() public {
        address nonGovernor = address(0x999);
        vm.stopPrank();
        vm.startPrank(nonGovernor);

        vm.expectRevert("UNAUTHORIZED");
        unbackedAccounting.addMonitoredContract(address(0x123), 1000e18);
    }

    function test_AccessControl_RemoveMonitoredContract() public {
        address nonGovernor = address(0x999);
        vm.stopPrank();
        vm.startPrank(nonGovernor);

        vm.expectRevert("UNAUTHORIZED");
        unbackedAccounting.removeMonitoredContract(address(0x123));
    }

    function test_AccessControl_Update() public {
        address nonExecutor = address(0x999);
        vm.stopPrank();
        vm.startPrank(nonExecutor);

        vm.expectRevert("UNAUTHORIZED");
        unbackedAccounting.update();
    }

    function test_ComplexScenario() public {
        // Setup multiple contracts with different scenarios
        address contract1 = address(0x123);
        address contract2 = address(0x456);
        address contract3 = address(0x789);

        // Add contracts
        unbackedAccounting.addMonitoredContract(contract1, 1000e18);
        unbackedAccounting.addMonitoredContract(contract2, 2000e18);
        unbackedAccounting.addMonitoredContract(contract3, 500e18);

        // Mint different amounts to each contract
        app.mint(contract1, 600e18); // 400 outflow (1000 - 600)
        app.mint(contract2, 1500e18); // 500 outflow (2000 - 1500)
        app.mint(contract3, 0); // 500 outflow (500 - 0)

        // Update
        unbackedAccounting.update();

        // Verify results
        assertEq(unbackedAccounting.totalOutflow(), 1400e18, "Total outflow mismatch"); // 400 + 500 + 500
        assertEq(unbackedAccounting.totalUnbackedSupply(), 3500e18, "Total unbacked supply mismatch"); // 1000 + 2000 + 500
        assertEq(unbackedAccounting.getNetUnbackedSupply(), 2100e18, "Net unbacked supply mismatch"); // 3500 - 1400 = 2100

        // Verify treasury was updated
        assertEq(treasury.unbackedSupply(), 2100e18, "Treasury unbacked supply mismatch");
    }

    function test_RemoveContractAndUpdate() public {
        address contract1 = address(0x123);
        address contract2 = address(0x456);

        // Add contracts
        unbackedAccounting.addMonitoredContract(contract1, 1000e18);
        unbackedAccounting.addMonitoredContract(contract2, 2000e18);

        // Mint to contracts
        app.mint(contract1, 600e18);
        app.mint(contract2, 1500e18);

        // Remove one contract
        unbackedAccounting.removeMonitoredContract(contract1);

        // Update
        unbackedAccounting.update();

        // Verify only remaining contract is considered
        assertEq(unbackedAccounting.totalOutflow(), 500e18); // Only contract2 outflow (2000 - 1500)
        assertEq(unbackedAccounting.totalUnbackedSupply(), 2000e18); // Only contract2 unbacked supply
        assertEq(unbackedAccounting.getNetUnbackedSupply(), 1500e18); // 2000 - 500 = 1500
    }

    function test_UpdateAfterBalanceChanges() public {
        address testContract = address(0x123);
        uint256 unbackedSupply = 1000e18;

        unbackedAccounting.addMonitoredContract(testContract, unbackedSupply);

        // Initial state (no balance)
        unbackedAccounting.update();
        assertEq(unbackedAccounting.totalOutflow(), 1000e18); // All tokens have left

        // Add some balance
        app.mint(testContract, 300e18);
        unbackedAccounting.update();
        assertEq(unbackedAccounting.totalOutflow(), 700e18); // 1000 - 300 = 700 tokens left

        // Add more balance
        app.mint(testContract, 400e18); // Total balance now 700
        unbackedAccounting.update();
        assertEq(unbackedAccounting.totalOutflow(), 300e18); // 1000 - 700 = 300 tokens left

        // Add enough balance to cover unbacked supply
        app.mint(testContract, 400e18); // Total balance now 1100
        unbackedAccounting.update();
        assertEq(unbackedAccounting.totalOutflow(), 0); // No tokens have left (balance > unbacked supply)
    }
}
