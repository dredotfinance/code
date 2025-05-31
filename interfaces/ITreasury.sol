// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5;

interface ITreasury {
  function deposit(
    uint256 _amount,
    address _token,
    uint256 _profit
  ) external returns (uint256);

  function withdraw(uint256 _amount, address _token) external;

  /**
   * @notice Returns the value of a token in DRE, 18 decimals
   * @param _token The address of the token
   * @param _amount The amount of the token
   * @return value_ The value of the token in DRE
   */
  function tokenValueE18(address _token, uint256 _amount) external view returns (uint256 value_);

  function mint(address _recipient, uint256 _amount) external;

  function manage(address _token, uint256 _amount) external;

  function excessReserves() external view returns (uint256);

  function totalReserves() external view returns (uint256);

  function calculateReserves() external view returns (uint256);

  function baseSupply() external view returns (uint256);

  /* ========== EVENTS ========== */

  event Deposit(address indexed token, uint256 amount, uint256 value);
  event Withdrawal(address indexed token, uint256 amount, uint256 value);
  event Managed(address indexed token, uint256 amount);
  event ReservesAudited(uint256 indexed totalReserves);
  event Minted(address indexed caller, address indexed recipient, uint256 amount);
  event Permissioned(address addr, bool result);
}
