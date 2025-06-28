// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../contracts/periphery/adapters/ShadowAdapter.sol";
import "../../contracts/interfaces/IShadowRouter.sol";
import "../../contracts/interfaces/ILiquidityAdapter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ShadowAdapterForkTest is Test {
    // Fork configuration
    uint256 public constant SONIC_BLOCK = 36249692;
    string public constant SONIC_RPC = "https://rpc.soniclabs.com";

    // Contract addresses from deployment script
    address public constant ROUTER = 0x1D368773735ee1E678950B7A97bcA2CafB330CDc;
    address public constant TOKEN_A = 0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5; // sCUSD
    address public constant TOKEN_B = 0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE; // RZR
    bool public constant STABLE = false;

    // Test addresses
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");

    // Contracts
    ShadowAdapter public adapter;
    IShadowRouter public router;
    IERC20 public tokenA;
    IERC20 public tokenB;

    // Events
    event LiquidityAdded(
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        bool stable,
        address indexed to
    );

    function setUp() public {
        // Fork Sonic mainnet at the specified block
        vm.createSelectFork(SONIC_RPC, SONIC_BLOCK);

        // Deploy the ShadowAdapter
        adapter = new ShadowAdapter(IShadowRouter(ROUTER), TOKEN_A, TOKEN_B, STABLE);

        // Initialize contract references
        router = IShadowRouter(ROUTER);
        tokenA = IERC20(TOKEN_A);
        tokenB = IERC20(TOKEN_B);

        // Label addresses for better trace output
        vm.label(address(adapter), "ShadowAdapter");
        vm.label(ROUTER, "ShadowRouter");
        vm.label(TOKEN_A, "sCUSD");
        vm.label(TOKEN_B, "RZR");
        vm.label(user, "User");
        vm.label(user2, "User2");

        // Fund test users with tokens
        _fundUser(user);
        _fundUser(user2);
    }

    function _fundUser(address _user) internal {
        // Fund with ETH for gas
        vm.deal(_user, 100 ether);

        // Fund with tokens (using existing balances on the fork)
        // Note: In a real fork test, you might need to swap or transfer tokens
        // For this test, we'll assume the user has some tokens or use a whale
        uint256 tokenABalance = tokenA.balanceOf(_user);
        uint256 tokenBBalance = tokenB.balanceOf(_user);

        console.log("User initial token A balance:", tokenABalance);
        console.log("User initial token B balance:", tokenBBalance);

        if (tokenABalance == 0) {
            // Try to get tokens from a whale or swap
            address whale = _findWhale(TOKEN_A);
            console.log("Found whale for token A:", whale);
            if (whale != address(0)) {
                uint256 whaleBalance = tokenA.balanceOf(whale);
                console.log("Whale token A balance:", whaleBalance);
                vm.prank(whale);
                tokenA.transfer(_user, 1000 * 10 ** 18); // Assume 18 decimals
                console.log("Transferred 1000 tokens to user");
            } else {
                console.log("No whale found for token A");
            }
        }

        if (tokenBBalance == 0) {
            address whale = _findWhale(TOKEN_B);
            console.log("Found whale for token B:", whale);
            if (whale != address(0)) {
                uint256 whaleBalance = tokenB.balanceOf(whale);
                console.log("Whale token B balance:", whaleBalance);
                vm.prank(whale);
                tokenB.transfer(_user, 1000 * 10 ** 18); // Assume 18 decimals
                console.log("Transferred 1000 tokens to user");
            } else {
                console.log("No whale found for token B");
            }
        }

        console.log("User final token A balance:", tokenA.balanceOf(_user));
        console.log("User final token B balance:", tokenB.balanceOf(_user));
    }

    function _findWhale(address token) internal view returns (address) {
        // Check for specific known whales first
        if (token == TOKEN_A) {
            // sCUSD whale with 67000 scUSD
            address scusdWhale = 0x5c170d1B1Fec191b70FcB099f9C8C42C0ED4aCFd;
            uint256 whaleBalance = IERC20(token).balanceOf(scusdWhale);
            console.log("sCUSD whale balance at", scusdWhale, ":", whaleBalance);
            if (whaleBalance > 1000 * 10 ** 18) {
                console.log("Found sCUSD whale with sufficient balance");
                return scusdWhale;
            } else {
                console.log("sCUSD whale balance too low");
            }
        }

        // Common whale addresses - you might need to adjust these
        address[] memory whales = new address[](5);
        whales[0] = 0x8894E0a0c962CB723c1976a4421c95949bE2D4E3; // Binance
        whales[1] = 0x28C6c06298d514Db089934071355E5743bf21d60; // Binance
        whales[2] = 0x21a31Ee1afC51d94C2eFcCAa2092aD1028285549; // Binance
        whales[3] = 0xDFd5293D8e347dFe59E90eFd55b2956a1343963d; // Binance
        whales[4] = 0x56Eddb7aa87536c09CCc2793473599fD21A8b17F; // Binance

        for (uint256 i = 0; i < whales.length; i++) {
            uint256 balance = IERC20(token).balanceOf(whales[i]);
            console.log("Whale", i, "balance:", balance);
            if (balance > 1000 * 10 ** 18) {
                console.log("Found whale", i, "with sufficient balance");
                return whales[i];
            }
        }
        console.log("No whale found with sufficient balance");
        return address(0);
    }

    function testAddLiquidity_fork_test() public {
        uint256 amountADesired = 100 * 10 ** 18; // 100 sCUSD
        uint256 amountBDesired = 50 * 10 ** 18; // 50 RZR
        uint256 amountAMin = 95 * 10 ** 18; // 5% slippage
        uint256 amountBMin = 47 * 10 ** 18; // 6% slippage

        uint256 userBalanceA = tokenA.balanceOf(user);
        uint256 userBalanceB = tokenB.balanceOf(user);

        assertGt(userBalanceA, amountADesired, "Insufficient token A balance");
        assertGt(userBalanceB, amountBDesired, "Insufficient token B balance");

        vm.startPrank(user);

        // Approve adapter to spend tokens
        tokenA.approve(address(adapter), amountADesired);
        tokenB.approve(address(adapter), amountBDesired);

        // Record balances before
        uint256 balanceBeforeA = tokenA.balanceOf(user);
        uint256 balanceBeforeB = tokenB.balanceOf(user);

        // Add liquidity
        (uint256 amountA, uint256 amountB, uint256 liquidity) =
            adapter.addLiquidity(amountADesired, amountBDesired, amountAMin, amountBMin);

        // Record balances after
        uint256 balanceAfterA = tokenA.balanceOf(user);
        uint256 balanceAfterB = tokenB.balanceOf(user);

        vm.stopPrank();

        // Verify results
        assertGt(liquidity, 0, "Should receive LP tokens");
        assertGe(amountA, amountAMin, "Amount A should be >= minimum");
        assertGe(amountB, amountBMin, "Amount B should be >= minimum");
        assertLe(amountA, amountADesired, "Amount A should be <= desired");
        assertLe(amountB, amountBDesired, "Amount B should be <= desired");

        // Verify token balances decreased
        assertLt(balanceAfterA, balanceBeforeA, "Token A balance should decrease");
        assertLt(balanceAfterB, balanceBeforeB, "Token B balance should decrease");

        // Verify adapter has no leftover tokens
        assertEq(tokenA.balanceOf(address(adapter)), 0, "Adapter should have no leftover token A");
        assertEq(tokenB.balanceOf(address(adapter)), 0, "Adapter should have no leftover token B");
    }
}
