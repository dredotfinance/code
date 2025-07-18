// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../core/AppAccessControlled.sol";
import "../interfaces/ILoyaltyList.sol";

/// @title LoyaltyList
/// @notice This contract manages a list of loyalty wallets and provides verification functionality
/// @dev Allows authorized contracts to verify if a wallet is a loyalty wallet
contract LoyaltyList is AppAccessControlled, ILoyaltyList {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Set of loyalty wallet addresses
    EnumerableSet.AddressSet private _loyaltyWallets;

    constructor(address _authority) {
        __AppAccessControlled_init(_authority);
    }

    /// @inheritdoc ILoyaltyList
    function addLoyaltyWallet(address _wallet) external onlyExecutor {
        _addLoyaltyWallet(_wallet);
    }

    /// @inheritdoc ILoyaltyList
    function addLoyaltyWalletsBatch(address[] calldata _wallets) external onlyExecutor {
        require(_wallets.length > 0, "LoyaltyList: Empty array");
        for (uint256 i = 0; i < _wallets.length; i++) {
            address wallet = _wallets[i];
            _addLoyaltyWallet(wallet);
        }
    }

    /// @inheritdoc ILoyaltyList
    function removeLoyaltyWallet(address _wallet) external onlyExecutor {
        _removeLoyaltyWallet(_wallet);
    }

    /// @inheritdoc ILoyaltyList
    function removeLoyaltyWalletsBatch(address[] calldata _wallets) external onlyExecutor {
        require(_wallets.length > 0, "LoyaltyList: Empty array");
        for (uint256 i = 0; i < _wallets.length; i++) {
            address wallet = _wallets[i];
            _removeLoyaltyWallet(wallet);
        }
    }

    /// @inheritdoc ILoyaltyList
    function isLoyaltyWallet(address _wallet) external view returns (bool) {
        return _loyaltyWallets.contains(_wallet);
    }

    /// @inheritdoc ILoyaltyList
    function getLoyaltyWalletCount() external view returns (uint256) {
        return _loyaltyWallets.length();
    }

    /// @inheritdoc ILoyaltyList
    function getLoyaltyWalletsPaginated(uint256 _offset, uint256 _limit) external view returns (address[] memory) {
        uint256 totalCount = _loyaltyWallets.length();
        require(_offset < totalCount, "LoyaltyList: Offset out of bounds");

        uint256 endIndex = _offset + _limit;
        if (endIndex > totalCount) {
            endIndex = totalCount;
        }

        uint256 resultLength = endIndex - _offset;
        address[] memory result = new address[](resultLength);

        for (uint256 i = 0; i < resultLength; i++) {
            result[i] = _loyaltyWallets.at(_offset + i);
        }

        return result;
    }

    /// @inheritdoc ILoyaltyList
    function areLoyaltyWallets(address[] calldata _wallets) external view returns (bool[] memory) {
        bool[] memory results = new bool[](_wallets.length);

        for (uint256 i = 0; i < _wallets.length; i++) {
            results[i] = _loyaltyWallets.contains(_wallets[i]);
        }

        return results;
    }

    /// @dev Internal function to add a loyalty wallet to the list
    /// @param _wallet The address of the loyalty wallet to add
    /// @return bool True if the wallet was added, false if it already existed
    function _addLoyaltyWallet(address _wallet) internal returns (bool) {
        require(_wallet != address(0), "LoyaltyList: Cannot add zero address");
        if (_loyaltyWallets.contains(_wallet)) {
            return false;
        }

        _loyaltyWallets.add(_wallet);
        emit LoyaltyWalletAdded(_wallet);
        return true;
    }

    /// @dev Internal function to remove a loyalty wallet from the list
    /// @param _wallet The address of the loyalty wallet to remove
    /// @return bool True if the wallet was removed, false if it didn't exist
    function _removeLoyaltyWallet(address _wallet) internal returns (bool) {
        require(_wallet != address(0), "LoyaltyList: Cannot remove zero address");
        if (!_loyaltyWallets.contains(_wallet)) {
            return false;
        }

        _loyaltyWallets.remove(_wallet);
        emit LoyaltyWalletRemoved(_wallet);
        return true;
    }
}
