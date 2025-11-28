// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title IMintableBurnableERC20
/// @notice This interface defines the standard functions for minting and burning an ERC20 token.
/// @dev Interface for ERC20 tokens with minting and burning capabilities.
interface IMintableBurnableERC20 {
    /// @notice Mints a specified amount of tokens to a given address.
    /// @dev The mint function increases the total supply of the token by minting tokens to the specified address.
    /// @param _to The address that will receive the newly minted tokens.
    /// @param _amount The amount of tokens to be minted.
    function mint(address _to, uint256 _amount) external;

    /// @notice Burns a specified amount of tokens from a given address.
    /// @dev The burn function reduces the total supply of the token by burning tokens from the specified address.
    /// @param _from The address from which the tokens will be burned.
    /// @param _amount The amount of tokens to be burned.
    function burn(address _from, uint256 _amount) external;
}
