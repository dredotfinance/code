// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IStaking4626 is IERC4626 {
    /// @notice Harvest rewards and compound them into the position
    function harvest() external;

    /// @notice Initialize a new position with an initial amount of assets
    /// @param amount The amount of assets to initialize the position with
    function initializePosition(uint256 amount) external;

    /// @notice Initialize the staking contract
    /// @param name The name of the staking contract
    /// @param symbol The symbol of the staking contract
    /// @param _staking The address of the staking contract
    /// @param _authority The address of the authority contract
    function initialize(string memory name, string memory symbol, address _staking, address _authority) external;

    /// @notice Set the buyout premium
    /// @param _buyoutPremiumBps The new buyout premium
    function setBuyoutPremiumBps(uint256 _buyoutPremiumBps) external;

    /// @notice Recreate the position
    function recreatePosition() external;

    /// @notice Emitted when rewards are compounded into the position
    /// @param amount The amount of rewards compounded
    event RewardsCompounded(uint256 amount);

    /// @notice Emitted when a new position is initialized
    /// @param amount The amount of assets initialized the position with
    event Staked(uint256 amount);

    /// @notice Emitted when the buyout premium is updated
    /// @param buyoutPremiumBps The new buyout premium
    event BuyoutPremiumBpsUpdated(uint256 buyoutPremiumBps);
}
