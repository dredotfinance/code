// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "./DreAccessControlled.sol";
import "./interfaces/IDreOracle.sol";
import "./interfaces/IDRE.sol";
import "./interfaces/IDreTreasury.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DreTreasury is DreAccessControlled, IDreTreasury, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    IDRE public dre;

    address[] public tokens;
    mapping(address => bool) public enabledTokens;
    IDreOracle public dreOracle;

    uint256 private _totalReserves;

    string internal notAccepted = "Treasury: not accepted";
    string internal invalidToken = "Treasury: invalid token";
    string internal insufficientReserves = "Treasury: insufficient reserves";

    /// @inheritdoc IDreTreasury
    uint256 public override creditReserves;

    /// @inheritdoc IDreTreasury
    uint256 public override unbackedSupply;

    function initialize(address _dre, address _dreOracle, address _authority) public reinitializer(5) {
        require(_dre != address(0), "Zero address: dre");
        require(_dreOracle != address(0), "Zero address: dreOracle");
        dre = IDRE(_dre);
        dreOracle = IDreOracle(_dreOracle);
        __Pausable_init();
        __DreAccessControlled_init(_authority);
        _updateReserves();
    }

    /// @inheritdoc IDreTreasury
    function setCreditReserves(uint256 _credit) external onlyPolicy {
        emit CreditReservesSet(_credit, creditReserves);
        creditReserves = _credit;
        _updateReserves();
    }

    /// @inheritdoc IDreTreasury
    function setUnbackedSupply(uint256 _unbacked) external onlyPolicy {
        require(_unbacked <= dre.totalSupply(), "Unbacked supply too high");
        emit UnbackedSupplySet(_unbacked, unbackedSupply);
        unbackedSupply = _unbacked;
        _updateReserves();
    }

    /// @inheritdoc IDreTreasury
    function deposit(uint256 _amount, address _token, uint256 _profit)
        external
        override
        nonReentrant
        whenNotPaused
        onlyReserveDepositor
        returns (uint256 send_)
    {
        require(enabledTokens[_token], invalidToken);

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 value = tokenValueE18(_token, _amount);

        // mint dre needed and store amount of rewards for distribution
        send_ = value - _profit;
        dre.mint(msg.sender, send_);

        _totalReserves += value;

        // invariant check
        require(_totalReserves >= actualSupply(), "Reserves too low");

        emit Deposit(_token, _amount, value);
    }

    /// @inheritdoc IDreTreasury
    function withdraw(uint256 _amount, address _token)
        external
        override
        nonReentrant
        whenNotPaused
        onlyReserveManager
    {
        require(enabledTokens[_token], notAccepted);

        uint256 value = tokenValueE18(_token, _amount);
        dre.transferFrom(msg.sender, address(this), value);
        dre.burn(value);

        _totalReserves = _totalReserves - value;
        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit Withdrawal(_token, _amount, value);
    }

    /// @inheritdoc IDreTreasury
    function manage(address _token, uint256 _amount)
        external
        override
        nonReentrant
        whenNotPaused
        onlyReserveManager
        returns (uint256 value_)
    {
        _updateReserves();
        if (enabledTokens[_token]) {
            value_ = tokenValueE18(_token, _amount);
            require(value_ <= excessReserves(), insufficientReserves);
            _totalReserves = _totalReserves - value_;
        }
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Managed(_token, _amount);
    }

    /// @inheritdoc IDreTreasury
    function mint(address _recipient, uint256 _amount) external override nonReentrant whenNotPaused onlyRewardManager {
        _updateReserves();
        require(_amount <= excessReserves(), insufficientReserves);
        dre.mint(_recipient, _amount);
        emit Minted(msg.sender, _recipient, _amount);
    }

    /// @inheritdoc IDreTreasury
    function syncReserves() external onlyExecutor {
        _updateReserves();
    }

    /// @inheritdoc IDreTreasury
    function enable(address _address) external onlyGovernor {
        require(_address != address(0), "Zero address");

        // DRE should not be enabled as a reserve; as this creates a circular dependency
        require(_address != address(dre), "DRE address");

        // add token into tokens array if not already added
        bool isAdded = false;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == _address) {
                isAdded = true;
                break;
            }
        }
        if (!isAdded) tokens.push(_address);

        enabledTokens[_address] = true;

        // ensure the token has a valid price in dreOracle contract
        require(dreOracle.getPriceInDre(_address) > 0, "Invalid price");
        emit TokenEnabled(_address, true);
    }

    /// @inheritdoc IDreTreasury
    function disable(address _toDisable) external onlyGuardianOrGovernor {
        enabledTokens[_toDisable] = false;
        emit TokenEnabled(_toDisable, false);
    }

    /// @inheritdoc IDreTreasury
    function backingRatioE18() public view returns (uint256) {
        return (totalReserves() * 1e18) / totalSupply();
    }

    /// @inheritdoc IDreTreasury
    function excessReserves() public view override returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        uint256 totalReserves_ = totalReserves();
        if (totalReserves_ <= totalSupply_) return 0;
        return totalReserves_ - totalSupply_;
    }

    /// @inheritdoc IDreTreasury
    function tokenValueE18(address _token, uint256 _amount) public view override returns (uint256 value_) {
        value_ = dreOracle.getPriceInDreForAmount(_token, _amount);
    }

    /// @inheritdoc IDreTreasury
    function actualReserves() public view override returns (uint256) {
        return _totalReserves;
    }

    /// @inheritdoc IDreTreasury
    function actualSupply() public view override returns (uint256) {
        return dre.totalSupply();
    }

    /// @inheritdoc IDreTreasury
    function totalReserves() public view override returns (uint256) {
        return _totalReserves + creditReserves;
    }

    /// @inheritdoc IDreTreasury
    function totalSupply() public view override returns (uint256) {
        return dre.totalSupply() - unbackedSupply;
    }

    /// @inheritdoc IDreTreasury
    function calculateReserves() public view override returns (uint256) {
        uint256 reserves = calculateActualReserves();
        return reserves + creditReserves;
    }

    /// @inheritdoc IDreTreasury
    function calculateActualReserves() public view override returns (uint256 reserves) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (enabledTokens[tokens[i]]) {
                uint256 balance = IERC20(tokens[i]).balanceOf(address(this));
                uint256 value = tokenValueE18(tokens[i], balance);
                reserves += value;
            }
        }
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
