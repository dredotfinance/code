// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../contracts/interfaces/IApp.sol";
import "../../contracts/interfaces/IAppTreasury.sol";
import "../../contracts/interfaces/IAppOracle.sol";
import "../../contracts/interfaces/IOracle.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract AuditSpotForkTest is Test {
    IAppTreasury public treasury;
    IAppOracle public oracle;
    IOracle public spotOracle;
    IApp public appToken;

    // Mainnet addresses
    address public constant TREASURY = 0xe22e10f8246dF1f0845eE3E9f2F0318bd60EFC85;
    address public constant ORACLE = 0x82884801428895c2550ED1CA96997BD60F74B5cC;
    address public constant SPOT_ORACLE = 0x953E6BCCCCcf01ae151A627b4C77718aC8cFaA34;
    address public constant APP_TOKEN = 0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5;
    address public constant GOVERNOR = 0x635ad38F96aEd1242DbB0DbB5E9125F560d87270;

    function setUp() public {
        uint256 mainnetFork = vm.createFork("https://rpc.soniclabs.com");
        vm.selectFork(mainnetFork);
        vm.roll(34407239);

        // Initialize contract instances
        treasury = IAppTreasury(TREASURY);
        oracle = IAppOracle(ORACLE);
        spotOracle = IOracle(SPOT_ORACLE);
        appToken = IApp(APP_TOKEN);

        // Label addresses for better debugging
        vm.label(TREASURY, "TREASURY");
        vm.label(ORACLE, "ORACLE");
        vm.label(SPOT_ORACLE, "SPOT_ORACLE");
        vm.label(APP_TOKEN, "APP_TOKEN");
        vm.label(GOVERNOR, "GOVERNOR");
    }

    // function test_AuditSpotPrice() public {
    //     // Get spot and floor prices
    //     uint256 spotPrice = spotOracle.getPrice();
    //     uint256 floorPrice = oracle.getTokenPrice();

    //     console.log("Spot price:", vm.toString(spotPrice));
    //     console.log("Floor price:", vm.toString(floorPrice));

    //     // Reset oracle to spot price
    //     vm.startPrank(GOVERNOR);
    //     oracle.setTokenPrice(spotPrice);
    //     vm.stopPrank();

    //     spotPrice = spotOracle.getPrice();
    //     floorPrice = oracle.getTokenPrice();

    //     console.log("New Spot price:", vm.toString(spotPrice));

    //     // Get all tokens from treasury
    //     address[] memory tokens = treasury.tokens();
    //     uint256 totalValue;

    //     for (uint256 i = 0; i < tokens.length; i++) {
    //         address token = tokens[i];
    //         IERC20Metadata tokenContract = IERC20Metadata(token);

    //         console.log("");
    //         console.log("Token name:", tokenContract.name());
    //         console.log("Token symbol:", tokenContract.symbol());
    //         console.log("Token decimals:", tokenContract.decimals());

    //         uint256 balance = tokenContract.balanceOf(TREASURY);
    //         console.log("Balance:", balance);
    //         console.log("Balance e18:", vm.toString(balance * 10 ** (18 - tokenContract.decimals())));

    //         uint256 tokenValue = treasury.tokenValueE18(token, balance);
    //         uint256 tokenValueE18 = tokenValue;
    //         console.log("Token value:", vm.toString(tokenValue));
    //         console.log("Token value e18:", vm.toString(tokenValueE18));
    //         console.log("Token value - spot price:", tokenValueE18 * spotPrice / 1e18);

    //         totalValue += tokenValueE18;
    //     }

    //     console.log("");
    //     console.log("Total value:", vm.toString(totalValue));
    //     console.log("Total value - spot price in USD:", totalValue * spotPrice / 1e18);
    // }
}
