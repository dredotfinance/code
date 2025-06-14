// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/StdInvariant.sol";
import "../BaseTest.sol";

/// @title PriceOracleInvariant
/// @notice Invariant tests for the Price Oracle system
///         Ensures the following always hold:
///         1. RZR token must always have 18 decimals
///         2. Token prices must be greater than 0
///         3. Floor price can only increase, never decrease
///         4. A new floor price must be less than 2x the previous floor price
contract PriceOracleInvariant is BaseTest {
    /// @dev Stores the previously observed floor price so we can compare against the
    ///      current value in each invariant run.
    uint256 private _lastFloorPrice;

    function setUp() public {
        // Deploy the full testing environment from BaseTest.
        setUpBaseTest();

        // Cache the initial floor price for later comparisons.
        _lastFloorPrice = appOracle.getTokenPrice();

        // Tell the forge invariant fuzzer which contracts it is allowed to call.
        // We limit it to the AppOracle and AppBurner contracts, as these are the
        // only contracts that are expected to mutate state relevant to the price
        // oracle invariants.
        targetContract(address(appOracle));
        targetContract(address(burner));

        // Use the governor/policy/executor address so that privileged functions
        // are callable during the invariant run.
        targetSender(owner);

        // Exclude selectors that could invalidate the environment in ways we
        // are not looking to test (e.g. replacing price oracles with ones that
        // return zero).
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("updateOracle(address,address)"));
        excludeSelector(StdInvariant.FuzzSelector({addr: address(appOracle), selectors: selectors}));

        // Exclude direct calls to `setTokenPrice(uint256)` so that floor price
        // can only be mutated via the `Burner` contract (which enforces the
        // 2x cap we are trying to test).
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("setTokenPrice(uint256)"));
        excludeSelector(StdInvariant.FuzzSelector({addr: address(appOracle), selectors: selectors2}));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Invariants
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice RZR token must always have 18 decimals.
    function invariant_RZRDecimalsIsEighteen() public view {
        assertEq(app.decimals(), 18, "RZR token must have 18 decimals");
    }

    /// @notice All tracked token prices must be strictly greater than zero.
    function invariant_TokenPricesArePositive() public view {
        // RZR floor price
        assertGt(appOracle.getTokenPrice(), 0);
        assertGt(appOracle.getPrice(address(app)), 0);

        // Mock tokens that were initialised in BaseTest
        assertGt(appOracle.getPrice(address(mockQuoteToken)), 0);
        assertGt(appOracle.getPrice(address(mockQuoteToken2)), 0);
        assertGt(appOracle.getPrice(address(mockQuoteToken3)), 0);
    }

    /// @notice The floor price must never decrease and each update must be less
    ///         than or equal to 2x the previous floor price.
    function invariant_FloorPriceMonotonicAndBounded() public {
        uint256 currentFloorPrice = appOracle.getTokenPrice();

        // Floor price can only increase (or stay constant).
        assertGe(currentFloorPrice, _lastFloorPrice, "Floor price decreased");

        // On each update, the floor price must be < 2x the previous price.
        // Skip the check if this is the very first invariant run where
        // `_lastFloorPrice` == current.
        if (_lastFloorPrice > 0) {
            assertLe(currentFloorPrice, _lastFloorPrice * 2, "Floor price increase exceeded 2x");
        }

        // Update state for the next invariant run.
        _lastFloorPrice = currentFloorPrice;
    }
}
