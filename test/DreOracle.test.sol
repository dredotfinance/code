// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./BaseTest.sol";
import "../contracts/DreOracle.sol";
import "../contracts/mocks/MockOracle.sol";
import "../contracts/mocks/MockERC20.sol";

contract DreOracleTest is BaseTest {
    MockERC20 public usdc;
    MockOracle public usdcPriceOracle;

    function setUp() public {
        setUpBaseTest();

        // Deploy tokens
        usdc = new MockERC20("USDC", "USDC");
        usdc.setDecimals(6);

        vm.startPrank(owner);

        // Deploy price oracles
        usdcPriceOracle = new MockOracle(1e18); // 1 USDC = $1

        // Set up oracles
        dreOracle.setDrePrice(1e18);
        dreOracle.updateOracle(address(usdc), address(usdcPriceOracle));
    }

    function test_Initialization() public view {
        assertEq(address(dreOracle.dre()), address(dre), "DRE token address should be set");
    }

    function test_UpdateOracle() public {
        // Create new oracle
        MockOracle newOracle = new MockOracle(2e18);

        // Update oracle as governor
        dreOracle.updateOracle(address(dre), address(newOracle));

        // Verify oracle was updated
        assertEq(address(dreOracle.oracles(dre)), address(newOracle), "Oracle should be updated");
    }

    function test_UpdateOracleReverts() public {
        vm.stopPrank();

        // Try to update oracle as non-governor
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        dreOracle.updateOracle(address(dre), address(mockOracle));

        // Try to update with zero address token
        vm.prank(owner);
        vm.expectRevert(IDreOracle.InvalidTokenAddress.selector);
        dreOracle.updateOracle(address(0), address(mockOracle));

        // Try to update with zero address oracle
        vm.prank(owner);
        vm.expectRevert(IDreOracle.InvalidOracleAddress.selector);
        dreOracle.updateOracle(address(dre), address(0));
    }

    function test_GetPrice() public {
        // Get USDC price
        uint256 usdcPrice = dreOracle.getPrice(address(usdc));
        assertEq(usdcPrice, 1e18, "USDC price should be 1 USD");

        // Update USDC price
        usdcPriceOracle.setPrice(2e18);
        usdcPrice = dreOracle.getPrice(address(usdc));
        assertEq(usdcPrice, 2e18, "USDC price should be 2 USD");
    }

    function test_GetPriceReverts() public {
        // Try to get price for non-existent oracle
        MockERC20 newToken = new MockERC20("NEW", "NEW");
        newToken.setDecimals(18);
        vm.expectRevert(abi.encodeWithSelector(IDreOracle.OracleNotFound.selector, address(newToken)));
        dreOracle.getPrice(address(newToken));
    }

    function test_GetPriceInDre() public {
        // Get USDC price in DRE
        uint256 usdcPriceInDre = dreOracle.getPriceInDre(address(usdc));
        assertEq(usdcPriceInDre, 1e18, "USDC price in DRE should be 1 DRE");

        // Update DRE price to $2
        dreOracle.setDrePrice(2e18);
        usdcPriceInDre = dreOracle.getPriceInDre(address(usdc));
        assertEq(usdcPriceInDre, 5e17, "USDC price in DRE should be 0.5 DRE");
    }

    function test_GetPriceInDreForAmount() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        uint256 price = dreOracle.getPriceInDreForAmount(address(usdc), amount);
        assertEq(price, 1000 * 1e18, "1000 USDC should be worth 1000 DRE");

        // Update DRE price to $2
        dreOracle.setDrePrice(2e18);
        price = dreOracle.getPriceInDreForAmount(address(usdc), amount);
        assertEq(price, 500 * 1e18, "1000 USDC should be worth 500 DRE");
    }

    function test_GetPriceForAmount() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        uint256 price = dreOracle.getPriceForAmount(address(usdc), amount);
        assertEq(price, 1000 * 1e18, "1000 USDC should be worth 1000 USD");

        // Update USDC price to $2
        usdcPriceOracle.setPrice(2e18);
        price = dreOracle.getPriceForAmount(address(usdc), amount);
        assertEq(price, 2000 * 1e18, "1000 USDC should be worth 2000 USD");
    }

    function test_DecimalHandling() public {
        // Create token with 8 decimals
        MockERC20 token8 = new MockERC20("TOKEN8", "TK8");
        token8.setDecimals(8);
        MockOracle oracle8 = new MockOracle(1e18);

        // Set up oracle
        dreOracle.updateOracle(address(token8), address(oracle8));

        // Test price calculations
        uint256 amount = 1000 * 1e8; // 1000 tokens
        uint256 price = dreOracle.getPriceForAmount(address(token8), amount);
        assertEq(price, 1000 * 1e18, "Price should be correctly scaled");

        uint256 priceInDre = dreOracle.getPriceInDreForAmount(address(token8), amount);
        assertEq(priceInDre, 1000 * 1e18, "Price in DRE should be correctly scaled");
    }

    function test_PriceUpdates() public {
        // Initial prices
        assertEq(dreOracle.getPrice(address(dre)), 1e18, "Initial DRE price should be 1 USD");
        assertEq(dreOracle.getPrice(address(usdc)), 1e18, "Initial USDC price should be 1 USD");

        // Update prices
        dreOracle.setDrePrice(2e18); // DRE = $2
        usdcPriceOracle.setPrice(1.5e18); // USDC = $1.5

        // Verify updated prices
        assertEq(dreOracle.getPrice(address(dre)), 2e18, "Updated DRE price should be 2 USD");
        assertEq(dreOracle.getPrice(address(usdc)), 1.5e18, "Updated USDC price should be 1.5 USD");

        // Verify price in DRE
        uint256 usdcPriceInDre = dreOracle.getPriceInDre(address(usdc));
        assertEq(usdcPriceInDre, 0.75e18, "USDC price in DRE should be 0.75 DRE");
    }
}
