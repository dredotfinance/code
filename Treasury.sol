// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
 import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "./interfaces/IDRE.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IAggregatorV3.sol";
import "./interfaces/IBondingCalculator.sol";
import "./DreAccessControlled.sol";

contract Treasury is ITreasury, Pausable, ReentrancyGuard, DreAccessControlled {
    using SafeERC20 for IERC20;

    IDRE public DRE;

    address[] public tokens;
    mapping(address => bool) public enabledTokens;
    mapping(address => AggregatorV3Interface) public oracles;

    uint256 public override totalReserves;
    uint256 public blocksNeededForQueue;

    uint256 public constant ORACLE_STALE_PERIOD = 1 hours;

    string internal notAccepted = "Treasury: not accepted";
    string internal invalidToken = "Treasury: invalid token";
    string internal insufficientReserves = "Treasury: insufficient reserves";

    function initialize(address _dre, uint256 _timelock, address _authority) public initializer {
        require(_dre != address(0), "Zero address: DRE");
        DRE = IDRE(_dre);
        blocksNeededForQueue = _timelock;

        __DreAccessControlled_init(_authority);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function deposit(
        uint256 _amount,
        address _token,
        uint256 _profit
    ) external override nonReentrant whenNotPaused returns (uint256 send_) {
        require(enabledTokens[_token], notAccepted);
        require(_amount > 0, "Treasury: deposit amount must be > 0");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 value = valueOf(_token, _amount);
        send_ = value.sub(_profit);
        DRE.mint(msg.sender, send_);

        totalReserves = totalReserves.add(value);
        emit ReservesUpdated(totalReserves);
    }

    function withdraw(uint256 _amount, address _token) external override nonReentrant whenNotPaused {
        require(enabledTokens[_token], notAccepted);
        require(_amount > 0, "Treasury: withdraw amount must be > 0");

        uint256 value = valueOf(_token, _amount);
        DRE.burnFrom(msg.sender, value);

        totalReserves = totalReserves.sub(value);
        emit ReservesUpdated(totalReserves);

        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function enable(address _token, address _oracle) external override onlyGovernor {
        require(_token != address(0), invalidToken);
        require(_oracle != address(0), "Treasury: invalid oracle");

        enabledTokens[_token] = true;
        oracles[_token] = AggregatorV3Interface(_oracle);
        tokens.push(_token);

        emit TokenEnabled(_token, _oracle);
    }

    function disable(address _token) external override onlyGovernor {
        require(enabledTokens[_token], invalidToken);

        enabledTokens[_token] = false;
        delete oracles[_token];

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == _token) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }

        emit TokenDisabled(_token);
    }

    function pause() external onlyGuardian {
        _pause();
    }

    function unpause() external onlyGuardian {
        _unpause();
    }

    /* ========== VIEW FUNCTIONS ========== */

    function valueOf(address _token, uint256 _amount) public view override returns (uint256 value_) {
        if (_amount == 0) return 0;

        AggregatorV3Interface oracle = oracles[_token];
        require(address(oracle) != address(0), "Treasury: invalid oracle");

        (, int256 price, , uint256 updatedAt, ) = oracle.latestRoundData();
        require(block.timestamp.sub(updatedAt) <= ORACLE_STALE_PERIOD, "Treasury: oracle price too old");

        uint256 decimals = IERC20Metadata(_token).decimals();
        value_ = _amount.mul(uint256(price)).div(10 ** decimals);
    }

    function excessReserves() public view override returns (uint256) {
        return totalReserves.sub(DRE.totalSupply());
    }
}
