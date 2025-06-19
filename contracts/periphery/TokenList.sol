// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title TokenList
/// @notice This contract is used to manage the list of tokens
contract TokenList is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _tokens;
    EnumerableSet.AddressSet private _lpTokens;

    constructor(address _owner) Ownable(_owner) {}

    function addToken(address _token) external onlyOwner {
        if (!_tokens.contains(_token)) {
            _tokens.add(_token);
        }
    }

    function addLpToken(address _token) external onlyOwner {
        if (!_lpTokens.contains(_token)) {
            _lpTokens.add(_token);
        }
    }

    function removeToken(address _token) external onlyOwner {
        _tokens.remove(_token);
    }

    function removeLpToken(address _token) external onlyOwner {
        _lpTokens.remove(_token);
    }

    function getTokens() external view returns (address[] memory) {
        return _tokens.values();
    }

    function getLpTokens() external view returns (address[] memory) {
        return _lpTokens.values();
    }
}
