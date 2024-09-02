// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CREATE3} from "solmate/utils/CREATE3.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {IMultiChainDeployer} from "./IMultiChainDeployer.sol";
import {L2YnOFTAdapterUpgradeable} from "src/L2YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "src/L2YnERC20Upgradeable.sol";

contract MultiChainDeployer is IMultiChainDeployer {
    event ContractCreated(address deployedAddress);
    /// @inheritdoc	IMultiChainDeployer

    function deploy(bytes32 salt, bytes memory creationCode)
        public
        payable
        override
        returns (address _deployedContract)
    {
        // hash salt with the deployer address to give each deployer its own namespace
        salt = keccak256(abi.encodePacked(msg.sender, salt));
        _deployedContract = CREATE3.deploy(salt, creationCode, msg.value);
        emit ContractCreated(_deployedContract);
    }

    function deployOFTAdapter(
        bytes32 salt,
        bytes memory creationCode,
        RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs
    ) public returns (address _deployedContract) {
        //deploy the contract with create3
        _deployedContract = deploy(salt, creationCode);
        // initialize the YnOFTAdapter
        initializeOFTAdapter(_deployedContract, _rateLimitConfigs);
    }

    function deployYnERC20(bytes32 salt, bytes memory creationCode, string memory _name, string memory _symbol)
        public
        returns (address _deployedContract)
    {
        //deploy the contract with create3
        _deployedContract = _deployedContract = deploy(salt, creationCode);
        // initialize the deployed ERC20
        initializeYnERC20Upgradeable(_deployedContract, _name, _symbol);
    }

    /// @inheritdoc	IMultiChainDeployer
    function getDeployed(address deployer, bytes32 salt) public view override returns (address deployed) {
        // hash salt with the deployer address to give each deployer its own namespace
        salt = keccak256(abi.encodePacked(deployer, salt));
        return CREATE3.getDeployed(salt);
    }

    function initializeOFTAdapter(address _deployedContract, RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs)
        public
    {
        L2YnOFTAdapterUpgradeable(_deployedContract).initialize(msg.sender, _rateLimitConfigs);
    }

    function initializeYnERC20Upgradeable(address _deployedContract, string memory _name, string memory _symbol)
        public
    {
        L2YnERC20Upgradeable(_deployedContract).initialize(_name, _symbol, msg.sender);
    }
}
