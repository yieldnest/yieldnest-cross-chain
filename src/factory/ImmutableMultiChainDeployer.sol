// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {IImmutableMultiChainDeployer} from "@/interfaces/IImmutableMultiChainDeployer.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";

contract ImmutableMultiChainDeployer is IImmutableMultiChainDeployer {
    /// @notice Emitted when a new contract is deployed
    /// @param _deployedAddress The address of the newly deployed contract
    event ContractCreated(address indexed _deployedAddress);

    /// @notice Mapping to track deployed addresses
    mapping(address => bool) private _deployedContracts;

    /// @dev Custom errors
    error InvalidSalt();
    error AlreadyDeployed();
    error IncorrectDeploymentAddress();

    /// @dev Modifier to ensure that the first 20 bytes of a submitted salt match
    /// those of the calling account, providing protection against salt misuse.
    /// @param _salt The salt value to check against the calling address.
    modifier containsCaller(bytes32 _salt) {
        if (address(bytes20(_salt)) != msg.sender && bytes20(_salt) != bytes20(0)) {
            revert InvalidSalt();
        }
        _;
    }

    /// @inheritdoc IImmutableMultiChainDeployer
    function deploy(
        bytes32 _salt,
        bytes memory _initCode
    )
        public
        payable
        override
        containsCaller(_salt)
        returns (address deployedContract)
    {
        address _targetDeploymentAddress = CREATE3.getDeployed(_salt);

        if (_deployedContracts[_targetDeploymentAddress]) {
            revert AlreadyDeployed();
        }

        deployedContract = CREATE3.deploy(_salt, _initCode, msg.value);

        if (_targetDeploymentAddress != deployedContract) {
            revert IncorrectDeploymentAddress();
        }

        _deployedContracts[deployedContract] = true;
        emit ContractCreated(deployedContract);
    }

    /// @inheritdoc IImmutableMultiChainDeployer
    function deployL2YnOFTAdapter(
        bytes32 _implSalt,
        bytes32 _proxySalt,
        address _token,
        address _lzEndpoint,
        address _owner,
        address _proxyController,
        bytes memory _l2YnOFTAdapterBytecode
    )
        public
        override
        returns (address deployedContract)
    {
        bytes memory _constructorParams = abi.encode(_token, _lzEndpoint);
        bytes memory _contractCode = abi.encodePacked(_l2YnOFTAdapterBytecode, _constructorParams);
        bytes memory _initializeArgs =
            abi.encodeWithSelector(L2YnOFTAdapterUpgradeable.initialize.selector, _owner);
        deployedContract =
            deployContractAndProxy(_implSalt, _proxySalt, _proxyController, _contractCode, _initializeArgs);
    }

    /// @inheritdoc IImmutableMultiChainDeployer
    function deployL2YnERC20(
        bytes32 _implSalt,
        bytes32 _proxySalt,
        string calldata _name,
        string calldata _symbol,
        address _owner,
        address _proxyController,
        bytes memory _l2YnERC20UpgradeableByteCode
    )
        public
        override
        returns (address deployedContract)
    {
        bytes memory _initializeArgs =
            abi.encodeWithSelector(L2YnERC20Upgradeable.initialize.selector, _name, _symbol, _owner);
        deployedContract = deployContractAndProxy(
            _implSalt, _proxySalt, _proxyController, _l2YnERC20UpgradeableByteCode, _initializeArgs
        );
    }

    /// @inheritdoc IImmutableMultiChainDeployer
    function getDeployed(bytes32 _salt) external view override returns (address deployed) {
        return CREATE3.getDeployed(_salt);
    }

    /// @inheritdoc IImmutableMultiChainDeployer
    function hasBeenDeployed(address _deploymentAddress) external view override returns (bool beenDeployed) {
        beenDeployed = _deployedContracts[_deploymentAddress];
    }

    /// @inheritdoc IImmutableMultiChainDeployer
    function deployProxy(
        bytes32 _salt,
        address _implementation,
        address _controller,
        bytes memory _initializeArgs
    )
        public
        returns (address proxy)
    {
        bytes memory _constructorParams = abi.encode(_implementation, _controller, _initializeArgs);
        bytes memory _contractCode =
            abi.encodePacked(type(TransparentUpgradeableProxy).creationCode, _constructorParams);
        proxy = deploy(_salt, _contractCode);
    }

    /// @inheritdoc IImmutableMultiChainDeployer
    function deployContractAndProxy(
        bytes32 _implSalt,
        bytes32 _proxySalt,
        address _controller,
        bytes memory _bytecode,
        bytes memory _initializeArgs
    )
        public
        returns (address addr)
    {
        address _implAddr = deploy(_implSalt, _bytecode);
        return deployProxy(_proxySalt, _implAddr, _controller, _initializeArgs);
    }
}
