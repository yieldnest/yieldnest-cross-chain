// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {IMintableBurnableERC20} from "./interfaces/IMintableBurnableERC20.sol";

contract L2YnERC20Upgradeable is ERC20Upgradeable, AccessControlUpgradeable, IMintableBurnableERC20 {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory _name, string memory _symbol, address _owner) public initializer {
        __ERC20_init(_name, _symbol);
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    function mint(address _to, uint256 _amount) public onlyRole(MINTER_ROLE) {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public onlyRole(MINTER_ROLE) {
        _burn(_from, _amount);
    }
}
