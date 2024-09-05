// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CREATE3} from "@solmate/utils/CREATE3.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {IImmutableMultiChainDeployer} from "@interfaces/IImmutableMultiChainDeployer.sol";
import {L2YnOFTAdapterUpgradeable} from "@adapters/L2YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@adapters/L2YnERC20Upgradeable.sol";
import "forge-std/console.sol";

contract ImmutableMultiChainDeployer is IImmutableMultiChainDeployer {
    event ContractCreated(address deployedAddress);

    // mapping to track the already deployed addresses
    mapping(address => bool) private _deployed;

    /// @dev Modifier to ensure that the first 20 bytes of a submitted salt match
    /// those of the calling account. This provides protection against the salt
    /// being stolen by frontrunners or other attackers. The protection can also be
    /// bypassed if desired by setting each of the first 20 bytes to zero.
    /// @param salt bytes32 The salt value to check against the calling address.
    modifier containsCaller(bytes32 salt) {
        // prevent contract submissions from being stolen from tx.pool by requiring
        // that the first 20 bytes of the submitted salt match msg.sender.
        require(
            (address(bytes20(salt)) == msg.sender) || (bytes20(salt) == bytes20(0)),
            "Invalid salt - first 20 bytes of the salt must match calling address."
        );
        _;
    }

    /// @inheritdoc	IImmutableMultiChainDeployer
    function deploy(bytes32 salt, bytes memory initCode)
        public
        payable
        override
        containsCaller(salt)
        returns (address _deployedContract)
    {
        // get target deployment
        address targetDeploymentAddress = CREATE3.getDeployed(salt);

        require(
            !_deployed[targetDeploymentAddress],
            "Invalid deployment. a contract has already been deployed at this address"
        );

        // use create 3 to deploy contract
        _deployedContract = CREATE3.deploy(salt, initCode, msg.value);

        // check address against target to make sure deployment was successful
        require(targetDeploymentAddress == _deployedContract, "failed to deploy to correct address");

        // record the deployment of the contract to prevent redeploys.
        _deployed[_deployedContract] = true;

        // emit event
        emit ContractCreated(_deployedContract);
    }

    /// @inheritdoc	IImmutableMultiChainDeployer
    function deployL2YnOFTAdapter(
        bytes32 _implSalt,
        bytes32 _proxySalt,
        address _token,
        address _lzEndpoint,
        address _owner,
        RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs,
        address _proxyController,
        bytes memory _l2YnOFTAdapterBytecode
    ) public returns (address _deployedContract) {
        bytes memory constructorParams = abi.encode(_token, _lzEndpoint);
        bytes memory contractCode = abi.encodePacked(_l2YnOFTAdapterBytecode, constructorParams);

        address adapterImpl = deploy(_implSalt, contractCode);
        _deployedContract = deployProxy(_proxySalt, adapterImpl, _proxyController);
        L2YnOFTAdapterUpgradeable(_deployedContract).initialize(_owner, _rateLimitConfigs);
    }

    /// @inheritdoc	IImmutableMultiChainDeployer
    function deployL2YnERC20(
        bytes32 _implSalt,
        bytes32 _proxySalt,
        string memory _name,
        string memory _symbol,
        address _owner,
        address _proxyController,
        bytes memory _l2YnERC20UpgradeableByteCode
    ) public returns (address _deployedContract) {
        address adapterImpl = deploy(_implSalt, _l2YnERC20UpgradeableByteCode);
        _deployedContract = deployProxy(_proxySalt, adapterImpl, _proxyController);
        L2YnERC20Upgradeable(_deployedContract).initialize(_name, _symbol, _owner);
    }

    /// @inheritdoc	IImmutableMultiChainDeployer
    function getDeployed(bytes32 salt) public view override returns (address deployed) {
        // hash salt with the deployer address to give each deployer its own namespace
        return CREATE3.getDeployed(salt);
    }

    function hasBeenDeployed(address deploymentAddress) external view returns (bool) {
        // determine if a contract has been deployed to the provided address.
        return _deployed[deploymentAddress];
    }

    function deployProxy(bytes32 salt, address implementation, address controller) internal returns (address proxy) {
        bytes memory bytecode = type(TransparentUpgradeableProxy).creationCode;
        bytes memory constructorParams = abi.encode(implementation, controller, "");
        bytes memory contractCode = abi.encodePacked(bytecode, constructorParams);
        proxy = deploy(salt, contractCode);
    }
}
