// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

/// @title Factory for deploying yieldnest contracts to deterministic addresses via CREATE3
/// @notice Enables deploying contracts using CREATE3 and then initializing the upgradeable contracts. Each deployer (msg.sender) has
/// its own namespace for deployed addresses.
/// @dev Uses CREATE3 for deterministic contract deployment.
interface IImmutableMultiChainDeployer {
    /// @notice Deploys a contract using CREATE3
    /// @dev The provided salt is combined with msg.sender to create a unique deployment address.
    /// @param salt A deployer-specific salt for determining the deployed contract's address.
    /// @param creationCode The creation code of the contract to deploy.
    /// @return deployed The address of the deployed contract.
    function deploy(bytes32 salt, bytes calldata creationCode) external payable returns (address deployed);

    /// @notice Deploys and initializes a deployOFTAdapter contract using CREATE3.
    /// @dev The provided salts and parameters are used to configure the deployment and initialization.
    /// @param _implSalt The salt for the OFT adapter implementation.
    /// @param _proxySalt The salt for the OFT adapter proxy.
    /// @param _token The token address for the OFT adapter.
    /// @param _lzEndpoint The LayerZero endpoint for the OFT adapter.
    /// @param _owner The owner address for the OFT adapter.
    /// @param _rateLimitConfigs The rate limit configurations for the OFT adapter.
    /// @param _proxyController The proxy controller address for the OFT adapter.
    /// @param _l2YnOFTAdapterBytecode The bytecode of the L2YnOFTAdapter contract to deploy.
    /// @return deployed The address of the deployed contract.
    function deployL2YnOFTAdapter(
        bytes32 _implSalt,
        bytes32 _proxySalt,
        address _token,
        address _lzEndpoint,
        address _owner,
        RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs,
        address _proxyController,
        bytes calldata _l2YnOFTAdapterBytecode
    ) external returns (address deployed);

    /// @notice Deploys and initializes a deployYnERC20 contract using CREATE3.
    /// @dev The provided salts and parameters are used to configure the deployment and initialization.
    /// @param _implSalt The salt for the ERC20 implementation.
    /// @param _proxySalt The salt for the ERC20 proxy.
    /// @param _name The name of the ERC20 token.
    /// @param _symbol The symbol of the ERC20 token.
    /// @param _owner The owner address of the ERC20 token.
    /// @param _proxyController The proxy controller address of the ERC20 token.
    /// @param _l2YnOFTAdapterBytecode The bytecode of the L2YnOFTAdapter contract to deploy.
    /// @return deployed The address of the deployed contract.
    function deployL2YnERC20(
        bytes32 _implSalt,
        bytes32 _proxySalt,
        string calldata _name,
        string calldata _symbol,
        address _owner,
        address _proxyController,
        bytes calldata _l2YnOFTAdapterBytecode
    ) external returns (address deployed);

    /// @notice Predicts the address of a contract deployed using CREATE3.
    /// @dev The provided salt is combined with the deployer address to create a unique predicted address.
    /// @param salt A deployer-specific salt for determining the deployed contract's address.
    /// @return deployed The address of the contract that will be deployed.
    function getDeployed(bytes32 salt) external view returns (address deployed);

    /// @notice Checks if a contract has already been deployed by the factory to a specific address.
    /// @param deploymentAddress The contract address to check.
    /// @return beenDeployed as true if the contract has been deployed, false otherwise.
    function hasBeenDeployed(address deploymentAddress) external view returns (bool beenDeployed);

    /// @notice Deploys a TransparentUpgradeableProxy with given parameters.
    /// @param salt The salt used for deployment.
    /// @param implementation The address of the implementation contract.
    /// @param controller The address of the proxy controller.
    /// @param _initializeArgs The initialization arguments for the proxy.
    /// @return proxy The address of the deployed proxy.
    function deployProxy(bytes32 salt, address implementation, address controller, bytes memory _initializeArgs)
        external
        returns (address proxy);

    /// @notice Deploys an implementation and proxy contract.
    /// @param _implSalt The salt used for the implementation deployment.
    /// @param _proxySalt The salt used for the proxy deployment.
    /// @param _controller The address of the proxy controller.
    /// @param _bytecode The bytecode of the implementation contract.
    /// @param _initializeArgs The initialization arguments for the proxy.
    /// @return addr The address of the deployed proxy.
    function deployContractAndProxy(
        bytes32 _implSalt,
        bytes32 _proxySalt,
        address _controller,
        bytes memory _bytecode,
        bytes memory _initializeArgs
    ) external returns (address addr);
}
