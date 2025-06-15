// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "./AppAccessControlled.sol";
import "../interfaces/IAppOracle.sol";
import "../interfaces/IApp.sol";
import "../interfaces/IAppTreasury.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AppTreasury is AppAccessControlled, IAppTreasury, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IApp;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IAppTreasury
    uint256 public immutable BASIS_POINTS = 10000; // 100%

    uint256 private _totalReserves;
    EnumerableSet.AddressSet private _tokens;

    IApp public app;

    /// @inheritdoc IAppTreasury
    IAppOracle public appOracle;

    /// @inheritdoc IAppTreasury
    uint256 public reserveFee;

    /// @inheritdoc IAppTreasury
    uint256 public override creditReserves;

    /// @inheritdoc IAppTreasury
    uint256 public override unbackedSupply;

    function initialize(address _app, address _appOracle, address _authority) public initializer {
        require(_app != address(0), "Zero address: app");
        require(_appOracle != address(0), "Zero address: appOracle");
        app = IApp(_app);
        appOracle = IAppOracle(_appOracle);
        __Pausable_init();
        __AppAccessControlled_init(_authority);
        __ReentrancyGuard_init();
        _updateReserves();
    }

    /// @inheritdoc IAppTreasury
    function setCreditReserves(uint256 _credit) external onlyPolicy {
        emit CreditReservesSet(_credit, creditReserves);
        creditReserves = _credit;
        _updateReserves();
    }

    /// @inheritdoc IAppTreasury
    function setReserveFee(uint256 _reserveFee) external onlyPolicy {
        require(_reserveFee <= BASIS_POINTS, "Invalid reserve fee");
        emit ReserveFeeSet(_reserveFee, reserveFee);
        reserveFee = _reserveFee;
    }

    /// @inheritdoc IAppTreasury
    function setUnbackedSupply(uint256 _unbacked) external onlyPolicy {
        require(_unbacked <= app.totalSupply(), "Unbacked supply too high");
        emit UnbackedSupplySet(_unbacked, unbackedSupply);
        unbackedSupply = _unbacked;
        _updateReserves();
    }

    /// @inheritdoc IAppTreasury
    function deposit(uint256 _amount, address _token, uint256 _profit)
        external
        override
        nonReentrant
        whenNotPaused
        onlyReserveDepositor
        returns (uint256 send_)
    {
        require(_tokens.contains(_token), "Treasury: invalid token");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        // send 10% to the treasury
        uint256 fee = _amount * reserveFee / BASIS_POINTS;
        IERC20(_token).safeTransfer(authority.operationsTreasury(), fee);
        _amount -= fee;

        uint256 value = tokenValueE18(_token, _amount);

        // mint app needed and store amount of rewards for distribution
        send_ = value - _profit;
        app.mint(msg.sender, send_);

        _totalReserves += value;

        // invariant check
        require(_totalReserves >= actualSupply(), "Reserves too low");

        emit Deposit(_token, _amount, value);
    }

    /// @inheritdoc IAppTreasury
    function withdraw(uint256 _amount, address _token)
        external
        override
        nonReentrant
        whenNotPaused
        onlyReserveManager
    {
        require(_tokens.contains(_token), "Treasury: not accepted");

        uint256 value = tokenValueE18(_token, _amount);
        app.safeTransferFrom(msg.sender, address(this), value);
        app.burn(value);

        _totalReserves = _totalReserves - value;
        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit Withdrawal(_token, _amount, value);
    }

    /// @inheritdoc IAppTreasury
    function manage(address _token, uint256 _amount)
        external
        override
        nonReentrant
        whenNotPaused
        onlyReserveManager
        returns (uint256 value_)
    {
        _updateReserves();
        if (_tokens.contains(_token)) {
            value_ = tokenValueE18(_token, _amount);
            require(value_ <= excessReserves(), "Treasury: insufficient reserves");
            _totalReserves = _totalReserves - value_;
        }
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Managed(_token, _amount);
    }

    /// @inheritdoc IAppTreasury
    function mint(address _recipient, uint256 _amount) external override nonReentrant whenNotPaused onlyPolicy {
        _updateReserves();
        require(_amount <= excessReserves(), "Treasury: insufficient reserves");
        app.mint(_recipient, _amount);
        emit Minted(msg.sender, _recipient, _amount);
    }

    /// @inheritdoc IAppTreasury
    function syncReserves() external onlyExecutor {
        _updateReserves();
    }

    /// @inheritdoc IAppTreasury
    function enable(address _address) external onlyGovernor {
        require(_address != address(0), "Zero address");

        // RZR should not be enabled as a reserve; as this creates a circular dependency
        require(_address != address(app), "RZR address");

        // add token into tokens array if not already added
        if (!_tokens.contains(_address)) {
            _tokens.add(_address);
        }

        // ensure the token has a valid price in appOracle contract
        require(appOracle.getPriceInToken(_address) > 0, "Invalid price");
        emit TokenEnabled(_address, true);
    }

    /// @inheritdoc IAppTreasury
    function disable(address _toDisable) external onlyGuardianOrGovernor {
        _tokens.remove(_toDisable);
        emit TokenEnabled(_toDisable, false);
    }

    /// @inheritdoc IAppTreasury
    function backingRatioE18() public view returns (uint256) {
        return (totalReserves() * 1e18) / totalSupply();
    }

    /// @inheritdoc IAppTreasury
    function excessReserves() public view override returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        uint256 totalReserves_ = totalReserves();
        if (totalReserves_ <= totalSupply_) return 0;
        return totalReserves_ - totalSupply_;
    }

    /// @inheritdoc IAppTreasury
    function tokenValueE18(address _token, uint256 _amount) public view override returns (uint256 value_) {
        value_ = appOracle.getPriceInTokenForAmount(_token, _amount);
    }

    /// @inheritdoc IAppTreasury
    function actualReserves() public view override returns (uint256) {
        return _totalReserves;
    }

    /// @inheritdoc IAppTreasury
    function actualSupply() public view override returns (uint256) {
        return app.totalSupply();
    }

    /// @inheritdoc IAppTreasury
    function totalReserves() public view override returns (uint256) {
        return _totalReserves + creditReserves;
    }

    /// @inheritdoc IAppTreasury
    function totalSupply() public view override returns (uint256) {
        return app.totalSupply() - unbackedSupply;
    }

    /// @inheritdoc IAppTreasury
    function calculateReserves() public view override returns (uint256) {
        uint256 reserves = calculateActualReserves();
        return reserves + creditReserves;
    }

    /// @inheritdoc IAppTreasury
    function calculateActualReserves() public view override returns (uint256 reserves) {
        for (uint256 i = 0; i < _tokens.length(); i++) {
            address token = _tokens.at(i);
            if (_tokens.contains(token)) {
                uint256 balance = IERC20(token).balanceOf(address(this));
                uint256 value = tokenValueE18(token, balance);
                reserves += value;
            }
        }
    }

    /// @inheritdoc IAppTreasury
    function tokens() public view returns (address[] memory) {
        return _tokens.values();
    }

    /// @inheritdoc IAppTreasury
    function tokenAt(uint256 _index) public view returns (address) {
        return _tokens.at(_index);
    }

    /// @inheritdoc IAppTreasury
    function enabledTokensLength() public view returns (uint256) {
        return _tokens.length();
    }

    /// @inheritdoc IAppTreasury
    function enabledTokens(address _token) public view override returns (bool) {
        return _tokens.contains(_token);
    }

    function _updateReserves() internal {
        _totalReserves = calculateActualReserves();
        emit ReservesAudited(_totalReserves, creditReserves, _totalReserves + creditReserves);
    }

    function pause() external onlyGuardian {
        _pause();
    }

    function unpause() external onlyGuardian {
        _unpause();
    }
}
