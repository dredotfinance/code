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

    uint256 public override totalReserves;

    string internal notAccepted = "Treasury: not accepted";
    string internal invalidToken = "Treasury: invalid token";
    string internal insufficientReserves = "Treasury: insufficient reserves";

    uint256 public credit;
    uint256 public debit;

    function initialize(address _dre, address _dreOracle, address _authority) public reinitializer(3) {
        require(_dre != address(0), "Zero address: dre");
        require(_dreOracle != address(0), "Zero address: dreOracle");
        dre = IDRE(_dre);
        dreOracle = IDreOracle(_dreOracle);
        __Pausable_init();
        __DreAccessControlled_init(_authority);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    event CreditDebitSet(uint256 credit, uint256 debit);

    function setCreditDebit(uint256 _credit, uint256 _debit) external onlyPolicy {
        credit = _credit;
        debit = _debit;
        emit CreditDebitSet(_credit, _debit);
    }

    /**
     * @notice allow approved address to deposit an asset for dre
     * @param _amount uint256 amount of token to deposit
     * @param _token address of token to deposit
     * @param _profit uint256 amount of profit to mint
     * @return send_ uint256 amount of dre minted
     */
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
    function withdraw(uint256 _amount, address _token)
        external
        override
        nonReentrant
        whenNotPaused
        onlyReserveManager
    {
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
    function syncReserves() external onlyExecutor {
        _updateReserves();
    }

    /**
     * @notice enable permission from queue or set staking contract
     * @param _address address to enable
     */
    function enable(address _address) external onlyGovernor {
        if (!enabledTokens[_address]) tokens.push(_address);
        enabledTokens[_address] = true;

        // ensure the token has a valid price in dreOracle contract
        require(dreOracle.getPriceInDre(_address) > 0, "Invalid price");
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
        value_ = dreOracle.getPriceInDreForAmount(_token, _amount);
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
        return reserves + credit - debit;
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
