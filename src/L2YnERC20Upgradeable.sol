// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {IMintableBurnableERC20} from "@/interfaces/IMintableBurnableERC20.sol";

/// @title L2YnERC20Upgradeable
/// @notice This contract implements an upgradeable ERC20 token with minting and burning capabilities, controlled
/// by roles.
/// @dev Inherits from OpenZeppelin's ERC20Upgradeable and AccessControlUpgradeable, and implements the
/// IMintableBurnableERC20 interface.
contract L2YnERC20Upgradeable is ERC20Upgradeable, AccessControlUpgradeable, IMintableBurnableERC20 {
    /// @notice Role identifier for accounts allowed to mint and burn tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Constructor that disables initializers to prevent direct initialization.
    /// @dev Uses OpenZeppelin's _disableInitializers to prevent the implementation contract from being
    /// initialized.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with a name, symbol, and assigns admin role to the owner.
    /// @dev This function must be called during the proxy deployment. It sets up the ERC20 token and grants the
    /// admin role.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    /// @param _owner The address that will be assigned the default admin role.
    function initialize(string memory _name, string memory _symbol, address _owner) public initializer {
        __ERC20_init(_name, _symbol);
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    /// @notice Mints a specified amount of tokens to a given address.
    /// @dev Only accounts with the MINTER_ROLE can call this function to mint tokens.
    /// @param _to The address that will receive the newly minted tokens.
    /// @param _amount The amount of tokens to be minted.
    function mint(address _to, uint256 _amount) public onlyRole(MINTER_ROLE) {
        _mint(_to, _amount);
    }

    /// @notice Burns a specified amount of tokens from a given address.
    /// @dev Only accounts with the MINTER_ROLE can call this function to burn tokens from a specified address.
    /// @param _from The address from which the tokens will be burned.
    /// @param _amount The amount of tokens to be burned.
    function burn(address _from, uint256 _amount) public onlyRole(MINTER_ROLE) {
        _burn(_from, _amount);
    }
}
