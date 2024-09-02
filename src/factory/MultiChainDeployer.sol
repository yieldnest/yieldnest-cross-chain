// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CREATE3} from "solmate/utils/CREATE3.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {IMultiChainDeployer} from "@interfaces/IMultiChainDeployer.sol";
import {L2YnOFTAdapterUpgradeable} from "@adapters/L2YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@adapters/L2YnERC20Upgradeable.sol";

contract MultiChainDeployer is IMultiChainDeployer {
    event ContractCreated(address deployedAddress);

    // mapping to track the already deployed addresses
    mapping(address => bool) private _deployed;

    // empty constructor
    constructor() public {}

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

    /// @inheritdoc	IMultiChainDeployer
    function deploy(bytes32 salt, bytes calldata creationCode)
        public
        payable
        override
        containsCaller(salt)
        returns (address _deployedContract)
    {
        // move the initialization code from calldata to memory.
        bytes memory initCode = initializationCode;

        // get target deployment
        address targetDeploymentAddress = getDeployed(msg.sender, salt);

        require(
            !_deployed[targetDeploymentAddress],
            "Invalid deployment. a contract has already been deployed at this address"
        );

        // use create 3 to deploy contract
        _deployedContract = CREATE3.deploy(salt, creationCode, msg.value);

        // check address against target to make sure deployment was successful
        require(targetDeploymentAddress == _deployedContract, "failed to deploy to correct address");

        // record the deployment of the contract to prevent redeploys.
        _deployed[_deployedContract] = true;

        // emit event
        emit ContractCreated(_deployedContract);
    }

    /// @inheritdoc	IMultiChainDeployer
    function deployOFTAdapter(
        bytes32 salt,
        bytes calldata creationCode,
        RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs
    ) public returns (address _deployedContract) {
        //deploy the contract with create3
        _deployedContract = this.deploy(salt, creationCode);
        // initialize the YnOFTAdapter
        initializeOFTAdapter(_deployedContract, _rateLimitConfigs);
    }

    /// @inheritdoc	IMultiChainDeployer
    function deployYnERC20(bytes32 salt, bytes calldata creationCode, string memory _name, string memory _symbol)
        public
        returns (address _deployedContract)
    {
        //deploy the contract with create3
        _deployedContract = _deployedContract = this.deploy(salt, creationCode);
        // initialize the deployed ERC20
        initializeYnERC20Upgradeable(_deployedContract, _name, _symbol);
    }

    /// @inheritdoc	IMultiChainDeployer
    function getDeployed(address deployer, bytes32 salt) public view override returns (address deployed) {
        // hash salt with the deployer address to give each deployer its own namespace
        salt = keccak256(abi.encodePacked(deployer, salt));
        return CREATE3.getDeployed(salt);
    }

    function hasBeenDeployed(address deploymentAddress) external view returns (bool) {
        // determine if a contract has been deployed to the provided address.
        return _deployed[deploymentAddress];
    }

    /// @inheritdoc	IMultiChainDeployer
    function initializeOFTAdapter(address _deployedContract, RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs)
        public
    {
        L2YnOFTAdapterUpgradeable(_deployedContract).initialize(msg.sender, _rateLimitConfigs);
    }

    /// @inheritdoc	IMultiChainDeployer
    function initializeYnERC20Upgradeable(address _deployedContract, string memory _name, string memory _symbol)
        public
    {
        L2YnERC20Upgradeable(_deployedContract).initialize(_name, _symbol, msg.sender);
    }
}
