// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseTest.sol";
import "../../contracts/core/AppOracle.sol";
import "../../contracts/mocks/MockOracle.sol";
import "../../contracts/mocks/MockERC20.sol";

contract AppOracleTest is BaseTest {
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
        appOracle.setTokenPrice(1e18);
        appOracle.updateOracle(address(usdc), address(usdcPriceOracle));
    }

    function test_Initialization() public view {
        assertEq(address(appOracle.app()), address(app), "RZR token address should be set");
    }

    function test_UpdateOracle() public {
        // Create new oracle
        MockOracle newOracle = new MockOracle(2e18);

        // Update oracle as governor
        appOracle.updateOracle(address(app), address(newOracle));

        // Verify oracle was updated
        assertEq(address(appOracle.oracles(app)), address(newOracle), "Oracle should be updated");
    }

    function test_UpdateOracleReverts() public {
        vm.stopPrank();

        // Try to update oracle as non-governor
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        appOracle.updateOracle(address(app), address(mockOracle));

        // Try to update with zero address token
        vm.prank(owner);
        vm.expectRevert(IAppOracle.InvalidTokenAddress.selector);
        appOracle.updateOracle(address(0), address(mockOracle));

        // Try to update with zero address oracle
        vm.prank(owner);
        vm.expectRevert(IAppOracle.InvalidOracleAddress.selector);
        appOracle.updateOracle(address(app), address(0));
    }

    function test_GetPrice() public {
        // Get USDC price
        uint256 usdcPrice = appOracle.getPrice(address(usdc));
        assertEq(usdcPrice, 1e18, "USDC price should be 1 USD");

        // Update USDC price
        usdcPriceOracle.setPrice(2e18);
        usdcPrice = appOracle.getPrice(address(usdc));
        assertEq(usdcPrice, 2e18, "USDC price should be 2 USD");
    }

    function test_GetPriceReverts() public {
        // Try to get price for non-existent oracle
        MockERC20 newToken = new MockERC20("NEW", "NEW");
        newToken.setDecimals(18);
        vm.expectRevert(abi.encodeWithSelector(IAppOracle.OracleNotFound.selector, address(newToken)));
        appOracle.getPrice(address(newToken));
    }

    function test_getPriceInToken() public {
        // Get USDC price in RZR
        uint256 usdcPriceInApp = appOracle.getPriceInToken(address(usdc));
        assertEq(usdcPriceInApp, 1e18, "USDC price in RZR should be 1 RZR");

        // Update RZR price to $2
        appOracle.setTokenPrice(2e18);
        usdcPriceInApp = appOracle.getPriceInToken(address(usdc));
        assertEq(usdcPriceInApp, 5e17, "USDC price in RZR should be 0.5 RZR");
    }

    function test_getPriceInTokenForAmount() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        uint256 price = appOracle.getPriceInTokenForAmount(address(usdc), amount);
        assertEq(price, 1000 * 1e18, "1000 USDC should be worth 1000 RZR");

        // Update RZR price to $2
        appOracle.setTokenPrice(2e18);
        price = appOracle.getPriceInTokenForAmount(address(usdc), amount);
        assertEq(price, 500 * 1e18, "1000 USDC should be worth 500 RZR");
    }

    function test_GetPriceForAmount() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        uint256 price = appOracle.getPriceForAmount(address(usdc), amount);
        assertEq(price, 1000 * 1e18, "1000 USDC should be worth 1000 USD");

        // Update USDC price to $2
        usdcPriceOracle.setPrice(2e18);
        price = appOracle.getPriceForAmount(address(usdc), amount);
        assertEq(price, 2000 * 1e18, "1000 USDC should be worth 2000 USD");
    }

    function test_DecimalHandling() public {
        // Create token with 8 decimals
        MockERC20 token8 = new MockERC20("TOKEN8", "TK8");
        token8.setDecimals(8);
        MockOracle oracle8 = new MockOracle(1e18);

        // Set up oracle
        appOracle.updateOracle(address(token8), address(oracle8));

        // Test price calculations
        uint256 amount = 1000 * 1e8; // 1000 tokens
        uint256 price = appOracle.getPriceForAmount(address(token8), amount);
        assertEq(price, 1000 * 1e18, "Price should be correctly scaled");

        uint256 priceInApp = appOracle.getPriceInTokenForAmount(address(token8), amount);
        assertEq(priceInApp, 1000 * 1e18, "Price in RZR should be correctly scaled");
    }

    function test_PriceUpdates() public {
        // Initial prices
        assertEq(appOracle.getPrice(address(app)), 1e18, "Initial RZR price should be 1 USD");
        assertEq(appOracle.getPrice(address(usdc)), 1e18, "Initial USDC price should be 1 USD");

        // Update prices
        appOracle.setTokenPrice(2e18); // RZR = $2
        usdcPriceOracle.setPrice(1.5e18); // USDC = $1.5

        // Verify updated prices
        assertEq(appOracle.getPrice(address(app)), 2e18, "Updated RZR price should be 2 USD");
        assertEq(appOracle.getPrice(address(usdc)), 1.5e18, "Updated USDC price should be 1.5 USD");

        // Verify price in RZR
        uint256 usdcPriceInApp = appOracle.getPriceInToken(address(usdc));
        assertEq(usdcPriceInApp, 0.75e18, "USDC price in RZR should be 0.75 RZR");
    }
}
