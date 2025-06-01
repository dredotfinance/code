// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "./DreAccessControlled.sol";
import "./interfaces/IAggregatorV3.sol";
import "./interfaces/IBondingCalculator.sol";
import "./interfaces/IDRE.sol";
import "./interfaces/ITreasury.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Treasury is DreAccessControlled, ITreasury, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    IDRE public dre;

    address[] public tokens;
    mapping(address => bool) public enabledTokens;
    mapping(address => AggregatorV3Interface) public oracles;

    uint256 public override totalReserves;
    uint256 public constant ORACLE_STALE_PERIOD = 1 hours;

    string internal notAccepted = "Treasury: not accepted";
    string internal invalidToken = "Treasury: invalid token";
    string internal insufficientReserves = "Treasury: insufficient reserves";

    function initialize(address _dre, address _authority) public initializer {
        require(_dre != address(0), "Zero address: dre");
        dre = IDRE(_dre);
        __Pausable_init();
        __DreAccessControlled_init(_authority);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice allow approved address to deposit an asset for dre
     * @param _amount uint256 amount of token to deposit
     * @param _token address of token to deposit
     * @param _profit uint256 amount of profit to mint
     * @return send_ uint256 amount of dre minted
     */
    function deposit(
        uint256 _amount,
        address _token,
        uint256 _profit
    ) external override nonReentrant whenNotPaused onlyReserveDepositor returns (uint256 send_) {
        require(enabledTokens[_token], invalidToken);

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 value = tokenValueE18(_token, _amount);

        // mint dre needed and store amount of rewards for distribution
        send_ = value - _profit;
        dre.mint(msg.sender, send_);

        totalReserves = totalReserves + value;

        // invariant check
        require(totalReserves >= dre.totalSupply(), "Reserves too low");

        emit Deposit(_token, _amount, value);
    }

    /**
     * @notice allow approved address to burn dre for reserves
     * @param _amount amount of dre to burn
     * @param _token address of the token to burn
     */
    function withdraw(uint256 _amount, address _token) external override nonReentrant whenNotPaused onlyReserveManager {
        require(enabledTokens[_token], notAccepted); // Only reserves can be used for redemptions

        uint256 value = tokenValueE18(_token, _amount);
        dre.transferFrom(msg.sender, address(this), value);
        dre.burn(value);

        totalReserves = totalReserves - value;
        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit Withdrawal(_token, _amount, value);
    }

    /**
     * @notice allow approved address to withdraw assets
     * @param _token address of the token to withdraw
     * @param _amount amount of the token to withdraw
     */
    function manage(address _token, uint256 _amount) external override nonReentrant whenNotPaused onlyReserveManager {
        if (enabledTokens[_token]) {
            uint256 value = tokenValueE18(_token, _amount);
            require(value <= excessReserves(), insufficientReserves);
            totalReserves = totalReserves - value;
        }
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Managed(_token, _amount);
    }

    /**
     * @notice mint new dre using excess reserves
     * @param _recipient address of the recipient
     * @param _amount amount of dre to mint
     */
    function mint(address _recipient, uint256 _amount) external override nonReentrant whenNotPaused onlyRewardManager {
        require(_amount <= excessReserves(), insufficientReserves);
        dre.mint(_recipient, _amount);
        emit Minted(msg.sender, _recipient, _amount);
    }

    /**
     * @notice takes inventory of all tracked assets
     * @notice always consolidate to recognized reserves before audit
     */
    function syncReserves() external onlyGovernor {
        _updateReserves();
    }

    /**
     * @notice enable permission from queue or set staking contract
     * @param _address address to enable
     * @param _oracle address of the oracle
     */
    function enable(address _address, address _oracle) external onlyGovernor {
        oracles[_address] = AggregatorV3Interface(_oracle);
        if (!enabledTokens[_address]) tokens.push(_address);
        enabledTokens[_address] = true;
        emit TokenEnabled(_address, true);
    }

    /**
     *  @notice disable permission from address
     *  @param _toDisable address
     */
    function disable(address _toDisable) external onlyGuardianOrGovernor {
        enabledTokens[_toDisable] = false;
        emit TokenEnabled(_toDisable, false);
    }

    /**
     * @notice check if registry contains address
     * @return (bool, uint256)
     */
    function indexInRegistry(address _address) public view returns (bool, uint256) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (_address == tokens[i]) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function backingRatioE18() public view returns (uint256) {
        return (totalReserves * 1e18) / dre.totalSupply();
    }

    /**
     * @notice returns excess reserves not backing tokens
     * @return uint
     */
    function excessReserves() public view override returns (uint256) {
        uint256 totalSupply = dre.totalSupply();
        if (totalSupply > totalReserves) return 0;
        return totalReserves - totalSupply;
    }

    /**
     * @notice returns dre valuation of asset
     * @param _token address of the token
     * @param _amount amount of the token
     * @return value_ value of the token in dre
     */
    function tokenValueE18(address _token, uint256 _amount) public view override returns (uint256 value_) {
        AggregatorV3Interface oracle = oracles[_token];
        require(address(oracle) != address(0), "Oracle not set");

        (, int256 priceE18, , uint256 updatedAt, ) = oracle.latestRoundData();
        require(block.timestamp - updatedAt <= ORACLE_STALE_PERIOD, "Stale price");
        require(priceE18 > 0, "Invalid price");

        uint256 decimals = oracle.decimals();
        value_ = (uint256(priceE18) * _amount) / (10 ** decimals);
    }

    /**
     * @notice returns supply metric that cannot be manipulated by debt
     * @dev use this any time you need to query supply
     * @return uint256
     */
    function baseSupply() external view override returns (uint256) {
        return dre.totalSupply();
    }

    /**
     * @notice calculates the total reserves of the treasury
     * @return uint256 total reserves
     */
    function calculateReserves() public view override returns (uint256) {
        uint256 reserves;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (enabledTokens[tokens[i]]) {
                uint256 balance = IERC20(tokens[i]).balanceOf(address(this));
                uint256 value = tokenValueE18(tokens[i], balance);
                reserves = reserves + value;
            }
        }
        return reserves;
    }

    function _updateReserves() internal {
        totalReserves = calculateReserves();
        emit ReservesAudited(totalReserves);
    }

    function pause() external onlyGuardian {
        _pause();
    }

    function unpause() external onlyGuardian {
        _unpause();
    }
}
