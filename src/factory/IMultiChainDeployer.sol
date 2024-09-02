// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.6.0;

import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

/// @title Factory for deploying contracts to deterministic addresses via CREATE3
/// @author zefram.eth
/// @notice Enables deploying contracts using CREATE3. Each deployer (msg.sender) has
/// its own namespace for deployed addresses.
interface IMultiChainDeployer {
    /// @notice Deploys a contract using CREATE3
    /// @dev The provided salt is hashed together with msg.sender to generate the final salt
    /// @param salt The deployer-specific salt for determining the deployed contract's address
    /// @param creationCode The creation code of the contract to deploy
    /// @return deployed The address of the deployed contract
    function deploy(bytes32 salt, bytes memory creationCode) external payable returns (address deployed);

    function deployOFTAdapter(
        bytes32 salt,
        bytes memory creationCode,
        RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs
    ) external returns (address deployed);

    function deployYnERC20(bytes32 salt, bytes memory creationCode, string memory _name, string memory _symbol)
        external
        returns (address deployed);
    /// @notice Predicts the address of a deployed contract
    /// @dev The provided salt is hashed together with the deployer address to generate the final salt
    /// @param deployer The deployer account that will call deploy()
    /// @param salt The deployer-specific salt for determining the deployed contract's address
    /// @return deployed The address of the contract that will be deployed
    function getDeployed(address deployer, bytes32 salt) external view returns (address deployed);

    function initializeOFTAdapter(address _deployedContract, RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs)
        external;

    function initializeYnERC20Upgradeable(address _deployedContract, string memory _name, string memory _symbol)
        external;
}
