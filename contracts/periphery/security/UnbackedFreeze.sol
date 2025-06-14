pragma solidity 0.8.28;

// SPDX-License-Identifier: AGPL-3.0

import "../../core/AppAccessControlled.sol";
import "../../interfaces/IAppTreasury.sol";

/**
 * @title UnbackedFreeze
 * @notice Contract that can be invoked by executors to evaluate the protocol's backing invariant and, if violated,
 *         attempt to pause critical protocol contracts (Treasury, Staking and Bond Depository).
 *
 * Bad debt is defined as:  actual RZR supply (including unbacked supply) minus total reserves (actual reserves + credit).
 * If the bad debt exceeds the configured `BAD_DEBT_THRESHOLD`, this contract will:
 *   1. Pause the Treasury (must implement `pause()` & be guardian-gated).
 *   2. Attempt to pause the Staking and Bond Depository contracts. These calls are executed using a low-level `call`
 *      and are therefore tolerant to targets that do not expose a `pause()` selector – the failure is simply emitted.
 */
contract UnbackedFreeze is AppAccessControlled {
    /* ========== EVENTS ========== */

    /// @notice Emitted on every evaluation attempt
    event InvariantEvaluated(uint256 badDebt, bool thresholdBreached);

    /// @notice Emitted for every pause attempt performed by this contract
    event PauseAttempt(address indexed target, bool success);

    /* ========== STATE VARIABLES ========== */

    // The Treasury – provides supply & reserve information and supports `pause()`
    IAppTreasury public immutable treasury;

    // Addresses of additional contracts to attempt pausing (e.g., Staking & Bond Depository)
    address public immutable staking;
    address public immutable bondDepository;

    /// @notice Maximum bad debt tolerated before triggering a pause (18-decimals, denominated in RZR)
    uint256 public constant BAD_DEBT_THRESHOLD = 10_000 * 1e18; // 10k RZR

    /* ========== CONSTRUCTOR ========== */

    constructor(address _treasury, address _staking, address _bondDepository, address _authority) {
        require(_treasury != address(0), "Zero address: treasury");
        require(_staking != address(0), "Zero address: staking");
        require(_bondDepository != address(0), "Zero address: bondDepository");
        __AppAccessControlled_init(_authority);

        treasury = IAppTreasury(_treasury);
        staking = _staking;
        bondDepository = _bondDepository;
    }

    /* ========== EXECUTOR ACTIONS ========== */

    /// @notice Evaluates the backing invariant and pauses contracts if it is violated.
    /// @dev Callable only by addresses with the EXECUTOR role in `AppAuthority`.
    function evaluateAndAct() external onlyExecutor {
        uint256 badDebt = _currentBadDebt();
        bool breached = badDebt > BAD_DEBT_THRESHOLD;

        emit InvariantEvaluated(badDebt, breached);

        if (breached) {
            _pauseProtocol();
        }
    }

    function act() public onlyExecutor {
        uint256 badDebt = _currentBadDebt();
        bool breached = badDebt > BAD_DEBT_THRESHOLD;
        require(breached, "Bad debt not breached");
        emit InvariantEvaluated(badDebt, breached);
        _pauseProtocol();
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @notice Returns the current bad debt (RZR supply minus total reserves).
    function currentBadDebt() external view returns (uint256) {
        return _currentBadDebt();
    }

    /* ========== INTERNAL HELPERS ========== */

    function _currentBadDebt() internal view returns (uint256) {
        // actualSupply includes unbacked supply; totalReserves already includes credit reserves.
        uint256 supply = treasury.actualSupply();
        uint256 reserves = treasury.totalReserves();
        return supply > reserves ? supply - reserves : 0;
    }

    function _pauseProtocol() internal {
        // 1. Pause Treasury (expects success)
        _safePause(address(treasury));

        // 2. Attempt to pause Staking & Bond Depository – their implementation might revert if selector missing.
        _safePause(staking);
        _safePause(bondDepository);
    }

    /// @dev Attempts to call `pause()` on a target contract; emits result instead of reverting on failure.
    function _safePause(address _target) private {
        (bool success,) = _target.call(abi.encodeWithSignature("pause()"));
        emit PauseAttempt(_target, success);
    }
}
