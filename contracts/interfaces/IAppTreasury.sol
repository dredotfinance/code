// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.15;

interface IAppTreasury {
    /**
     * @notice allow approved address to deposit an asset for app
     * @param _amount uint256 amount of token to deposit
     * @param _token address of token to deposit
     * @param _profit uint256 amount of profit to mint
     * @return send_ uint256 amount of app minted
     */
    function deposit(uint256 _amount, address _token, uint256 _profit) external returns (uint256 send_);

    /**
     * @notice allow approved address to burn app for reserves
     * @param _amount amount of app to burn
     * @param _token address of the token to burn
     */
    function withdraw(uint256 _amount, address _token) external;

    /**
     * @notice Returns the value of a token in App, 18 decimals
     * @param _token The address of the token
     * @param _amount The amount of the token
     * @return value_ The value of the token in App
     */
    function tokenValueE18(address _token, uint256 _amount) external view returns (uint256 value_);

    /**
     * @notice allow approved address to mint app
     * @param _recipient address of the recipient
     * @param _amount amount of app to mint
     */
    function mint(address _recipient, uint256 _amount) external;

    /**
     * @notice allow approved address to manage the reserves of the treasury
     * @param _token address of the token to manage
     * @param _amount amount of the token to manage
     * @return value amount of app that was managed
     */
    function manage(address _token, uint256 _amount) external returns (uint256 value);

    /**
     * @notice allow approved address to enable a token as a reserve
     * @param _address address to enable
     */
    function enable(address _address) external;

    /**
     * @notice Returns the backing ratio of the treasury in App terms (1e18)
     * @return backingRatio_ The backing ratio (1e18)
     */
    function backingRatioE18() external view returns (uint256);

    /**
     * @notice allow approved address to disable a token as a reserve
     * @param _address address to disable
     */
    function disable(address _address) external;

    /**
     * @notice Sets the credit reserves of the treasury
     * @param _credit The amount of reserves (in App terms) that has been credited to the treasury but not yet deposited
     */
    function setCreditReserves(uint256 _credit) external;

    /**
     * @notice Sets the unbacked supply of the treasury
     * @param _unbacked The amount of App that is in the minted but not yet backed
     */
    function setUnbackedSupply(uint256 _unbacked) external;

    /**
     * @notice Credit is amount of reserves (in App terms) that has been credited to the treasury but
     * not yet deposited in. This is important in the case that the collateral asset for App exists somewhere else
     * (such as in an RWA for example).
     *
     * This is particulary important in case of PSM modules where App is minted into a lending protocol for example
     * and App is taken out only when it it being borrowed with an over-collateralized position.
     *
     * @dev Credit is not included in the total supply of App.
     * @return credit_ The amount of reserves (in App terms) that has been credited to the treasury but not yet minted
     */
    function creditReserves() external view returns (uint256 credit_);

    /**
     * @notice Returns the actual supply of App excluding credit
     * @return actualSupply_ The actual supply of App excluding credit
     */
    function actualSupply() external view returns (uint256 actualSupply_);

    /**
     * @notice Returns the amount of App that has been minted but not yet backed
     * @return unbackedSupply_ The amount of App
     */
    function unbackedSupply() external view returns (uint256 unbackedSupply_);

    /**
     * @notice Returns the excess reserves of the treasury in App terms (excluding credit and debit)
     * that is not backing the App supply
     * @return excessReserves_ The excess reserves of the treasury in App terms
     */
    function excessReserves() external view returns (uint256);

    /**
     * @notice Returns the total reserves of the treasury in App terms (including credit and debit)
     * @return totalReserves_ The total reserves of the treasury in App terms
     */
    function totalReserves() external view returns (uint256);

    /**
     * @notice Returns the total supply of App (including credit and debit)
     * @return totalSupply_ The total supply of App
     */
    function totalSupply() external view returns (uint256 totalSupply_);

    /**
     * @notice Returns the actual reserves of the treasury in App terms excluding credit and debit
     * @return actualReserves_ The actual reserves of the treasury in App terms
     */
    function actualReserves() external view returns (uint256 actualReserves_);

    /**
     * @notice Syncs the reserves of the treasury
     */
    function syncReserves() external;

    /**
     * @notice Calculates the total reserves of the treasury in App terms (including credit and debit)
     * @return reserves_ The total reserves of the treasury in App terms
     */
    function calculateReserves() external view returns (uint256 reserves_);

    /**
     * @notice Calculates the actual reserves of the treasury in App terms excluding credit and debit
     * @return actualReserves_ The actual reserves of the treasury in App terms
     */
    function calculateActualReserves() external view returns (uint256 actualReserves_);

    /* ========== EVENTS ========== */

    event Deposit(address indexed token, uint256 amount, uint256 value);
    event Withdrawal(address indexed token, uint256 amount, uint256 value);
    event Managed(address indexed token, uint256 amount);
    event ReservesAudited(
        uint256 indexed totalReserves, uint256 indexed creditReserves, uint256 indexed totalReservesWithCredit
    );
    event Minted(address indexed caller, address indexed recipient, uint256 amount);
    event TokenEnabled(address addr, bool result);
    event CreditReservesSet(uint256 newCredit, uint256 oldCredit);
    event UnbackedSupplySet(uint256 newUnbacked, uint256 oldUnbacked);
}
