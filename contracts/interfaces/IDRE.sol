// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IDRE
/// @notice Interface for the DRE token contract
/// @dev Extends ERC20 with additional functionality for burning and minting
interface IDRE is IERC20 {
    /// @notice Mints new DRE tokens
    /// @param to Address to receive the minted tokens
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) external;

    /// @notice Burns DRE tokens
    /// @param amount Amount of tokens to burn
    function burn(uint256 amount) external;
}
