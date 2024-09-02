// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.6.0;

import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

/// @title Factory for deploying yieldnest contracts to deterministic addresses via CREATE3
/// @author Raid Guild
/// @notice Enables deploying contracts using CREATE3 and then initializing the upgradeable contracts. Each deployer (msg.sender) has
/// its own namespace for deployed addresses.
interface IMultiChainDeployer {
    /// @notice Deploys a contract using CREATE3
    /// @dev The provided salt is hashed together with msg.sender to generate the final salt
    /// @param salt The deployer-specific salt for determining the deployed contract's address
    /// @param creationCode The creation code of the contract to deploy
    /// @return deployed The address of the deployed contract
    function deploy(bytes32 salt, bytes calldata creationCode) external payable returns (address deployed);

    /// @notice Deploys a deployOFTAdapter contract using CREATE3 and initializes in the same call
    /// @dev The provided salt is hashed together with msg.sender to generate the final salt
    /// @param salt The deployer-specific salt for determining the deployed contract's address
    /// @param creationCode The creation code of the contract to deploy
    /// @param _rateLimitConfigs the desired rate limit configs for the oft adapter to be passed to the initializer
    /// @return deployed The address of the deployed contract
    function deployOFTAdapter(
        bytes32 salt,
        bytes calldata creationCode,
        RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs
    ) external returns (address deployed);

    /// @notice Deploys a deployYnERC20 contract using CREATE3 and initializes in the same call
    /// @dev The provided salt is hashed together with msg.sender to generate the final salt
    /// @param salt The deployer-specific salt for determining the deployed contract's address
    /// @param creationCode The creation code of the contract to deploy
    /// @param _name the name of the erc20 to be passed to the initializer
    /// @param _symbol the symbol of the erc20 to be passed to the initializer
    /// @return deployed The address of the deployed contract
    function deployYnERC20(bytes32 salt, bytes calldata creationCode, string memory _name, string memory _symbol)
        external
        returns (address deployed);

    /// @notice Predicts the address of a deployed contract
    /// @dev The provided salt is hashed together with the deployer address to generate the final salt
    /// @param deployer The deployer account that will call deploy()
    /// @param salt The deployer-specific salt for determining the deployed contract's address
    /// @return deployed The address of the contract that will be deployed
    function getDeployed(address deployer, bytes32 salt) external view returns (address deployed);

    /// @dev Determine if a contract has already been deployed by the factory to a
    /// given address.
    /// @param deploymentAddress address The contract address to check.
    /// @return True if the contract has been deployed, false otherwise.
    function hasBeenDeployed(address deploymentAddress) external view returns (bool);

    /// @notice Initializes a deployed YnOFTAdapter
    /// @dev This is intended to be called atomically in the deployOFTAdapter, but can be called seperatly as well
    /// @param _deployedContract the address of the deployed contract
    /// @param _rateLimitConfigs the desired rate limit configs for the oft adapter
    function initializeOFTAdapter(address _deployedContract, RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs)
        external;

    /// @notice Initializes a deployed YnERC20Upgradeable contract
    /// @dev This is intended to be called atomically in the deployYnERC20 call, but can be called seperatly as well
    /// @param _deployedContract the address of the deployed contract
    /// @param _name the name of the erc20
    /// @param _symbol the symbol of the erc20
    function initializeYnERC20Upgradeable(address _deployedContract, string memory _name, string memory _symbol)
        external;
}
