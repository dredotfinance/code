// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILoyaltyList {
    /// @notice Event emitted when a loyalty wallet is added
    /// @param wallet The address of the loyalty wallet that was added
    event LoyaltyWalletAdded(address indexed wallet);

    /// @notice Event emitted when a loyalty wallet is removed
    /// @param wallet The address of the loyalty wallet that was removed
    event LoyaltyWalletRemoved(address indexed wallet);

    /// @notice Adds a single loyalty wallet to the list
    /// @dev Only callable by the owner
    /// @param _wallet The address of the loyalty wallet to add
    function addLoyaltyWallet(address _wallet) external;

    /// @notice Adds multiple loyalty wallets to the list in a single transaction
    /// @dev Only callable by the owner
    /// @param _wallets Array of loyalty wallet addresses to add
    function addLoyaltyWalletsBatch(address[] calldata _wallets) external;

    /// @notice Removes a single loyalty wallet from the list
    /// @dev Only callable by the owner
    /// @param _wallet The address of the loyalty wallet to remove
    function removeLoyaltyWallet(address _wallet) external;

    /// @notice Removes multiple loyalty wallets from the list in a single transaction
    /// @dev Only callable by the owner
    /// @param _wallets Array of loyalty wallet addresses to remove
    function removeLoyaltyWalletsBatch(address[] calldata _wallets) external;

    /// @notice Checks if a wallet is a loyalty wallet
    /// @param _wallet The address to check
    /// @return bool True if the wallet is a loyalty wallet, false otherwise
    function isLoyaltyWallet(address _wallet) external view returns (bool);

    /// @notice Returns the total number of loyalty wallets
    /// @return uint256 The total count of loyalty wallets
    function getLoyaltyWalletCount() external view returns (uint256);

    /// @notice Returns a paginated list of loyalty wallet addresses
    /// @dev Useful for large lists to avoid gas limit issues
    /// @param _offset The starting index for pagination
    /// @param _limit The maximum number of addresses to return
    /// @return address[] Array of loyalty wallet addresses for the given page
    function getLoyaltyWalletsPaginated(uint256 _offset, uint256 _limit) external view returns (address[] memory);

    /// @notice Checks if multiple wallets are loyalty wallets
    /// @param _wallets Array of addresses to check
    /// @return bool[] Array of boolean values indicating if each wallet is a loyalty wallet
    function areLoyaltyWallets(address[] calldata _wallets) external view returns (bool[] memory);
}
