/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseData} from "./BaseData.s.sol";

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {ImmutableMultiChainDeployer} from "@/factory/ImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {EndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/EndpointV2.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts-5/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Utils} from "script/Utils.sol";

import {console} from "forge-std/console.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

struct RateLimitConfig {
    uint256 limit;
    uint256 window;
}

struct BaseInput {
    string erc20Name;
    string erc20Symbol;
    uint256 l1ChainId;
    address l1ERC20Address;
    uint256[] l2ChainIds;
    RateLimitConfig rateLimitConfig;
}

struct Deployment {
    ChainDeployment[] chains;
    address deployerAddress;
    string erc20Name;
    string erc20Symbol;
}

struct ChainDeployment {
    uint256 chainId;
    address erc20Address;
    bool isL1;
    address lzEndpoint;
    uint32 lzEID;
    address multiChainDeployer;
    address oftAdapter;
}

struct PredictedAddresses {
    address l1OFTAdapter;
    address l2MultiChainDeployer;
    address l2ERC20;
    address l2OFTAdapter;
}

struct PeerConfig {
    uint32 eid;
    address peer;
}

contract BaseScript is BaseData, Utils {
    using Bytes32AddressLib for bytes32;

    BaseInput public baseInput;
    Deployment public deployment;
    ChainDeployment public currentDeployment;
    PredictedAddresses public predictions;
    string private constant _version = "v0.0.3";

    function _getRateLimitConfigs() internal view returns (RateLimiter.RateLimitConfig[] memory) {
        RateLimiter.RateLimitConfig[] memory rateLimitConfigs =
            new RateLimiter.RateLimitConfig[](baseInput.l2ChainIds.length + 1);
        rateLimitConfigs[0] = RateLimiter.RateLimitConfig(
            getEID(baseInput.l1ChainId), baseInput.rateLimitConfig.limit, baseInput.rateLimitConfig.window
        );
        for (uint256 i; i < baseInput.l2ChainIds.length; i++) {
            rateLimitConfigs[i + 1] = RateLimiter.RateLimitConfig(
                getEID(baseInput.l2ChainIds[i]), baseInput.rateLimitConfig.limit, baseInput.rateLimitConfig.window
            );
        }
        return rateLimitConfigs;
    }

    function _loadInput(string calldata _inputPath) internal {
        _loadJson(_inputPath);
        _validateInput();
        bool isL1 = _getIsL1();
        _loadDeployment();
        if (deployment.deployerAddress != address(0)) {
            require(deployment.deployerAddress == msg.sender, "Invalid Deployer");
        }
        for (uint256 i; i < deployment.chains.length; i++) {
            if (deployment.chains[i].chainId == block.chainid) {
                currentDeployment = deployment.chains[i];
                break;
            }
        }
        currentDeployment.chainId = block.chainid;
        currentDeployment.isL1 = isL1;
        if (isL1) {
            currentDeployment.erc20Address = baseInput.l1ERC20Address;
        }
        currentDeployment.lzEndpoint = getData(block.chainid).LZ_ENDPOINT;
        currentDeployment.lzEID = getEID(block.chainid);
        _loadPredictions();
        require(
            deployment.deployerAddress == address(0) || deployment.deployerAddress == msg.sender,
            "Invalid Deployer Address"
        );
    }

    function _computeCreate3Address(bytes32 _salt, address _deployer) internal pure returns (address) {
        bytes memory PROXY_BYTECODE = hex"67363d3d37363d34f03d5260086018f3";

        bytes32 PROXY_BYTECODE_HASH = keccak256(PROXY_BYTECODE);
        address proxy =
            keccak256(abi.encodePacked(bytes1(0xFF), _deployer, _salt, PROXY_BYTECODE_HASH)).fromLast20Bytes();

        return keccak256(abi.encodePacked(hex"d694", proxy, hex"01")).fromLast20Bytes();
    }

    function _loadPredictions() internal {
        {
            bytes32 salt = createImmutableMultiChainDeployerSalt(msg.sender);

            address predictedAddress =
                vm.computeCreate2Address(salt, keccak256(type(ImmutableMultiChainDeployer).creationCode));
            predictions.l2MultiChainDeployer = predictedAddress;
        }

        {
            bytes32 proxySalt = createL1YnOFTAdapterUpgradeableProxySalt(msg.sender);
            bytes32 implementationSalt = createL1YnOFTAdapterUpgradeableSalt(msg.sender);

            bytes memory implBytecode = bytes.concat(
                type(L1YnOFTAdapterUpgradeable).creationCode,
                abi.encode(baseInput.l1ERC20Address, getData(block.chainid).LZ_ENDPOINT)
            );

            address implPredictedAddress = vm.computeCreate2Address(implementationSalt, keccak256(implBytecode));

            bytes memory initializeData =
                abi.encodeWithSelector(L1YnOFTAdapterUpgradeable.initialize.selector, msg.sender);

            bytes memory proxyBytecode = bytes.concat(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(implPredictedAddress, msg.sender, initializeData)
            );

            address predictedAddress = vm.computeCreate2Address(proxySalt, keccak256(proxyBytecode));
            predictions.l1OFTAdapter = predictedAddress;
        }

        {
            bytes32 salt = createL2YnOFTAdapterUpgradeableProxySalt(msg.sender);

            address predictedAddress = _computeCreate3Address(salt, predictions.l2MultiChainDeployer);
            predictions.l2OFTAdapter = predictedAddress;
        }

        {
            bytes32 salt = createL2YnERC20UpgradeableProxySalt(msg.sender);
            address predictedAddress = _computeCreate3Address(salt, predictions.l2MultiChainDeployer);
            predictions.l2ERC20 = predictedAddress;
        }

        // console.log("Predicted MultiChainDeployer: %s", predictions.l2MultiChainDeployer);
        // console.log("Predicted L1OFTAdapter: %s", predictions.l1OFTAdapter);
        // console.log("Predicted L2OFTAdapter: %s", predictions.l2OFTAdapter);
        // console.log("Predicted L2ERC20: %s", predictions.l2ERC20);
    }

    function _validateInput() internal view {
        require(bytes(baseInput.erc20Name).length > 0, "Invalid ERC20 Name");
        require(bytes(baseInput.erc20Symbol).length > 0, "Invalid ERC20 Symbol");
        require(baseInput.rateLimitConfig.limit > 0, "Invalid Rate Limit");
        require(baseInput.rateLimitConfig.window > 0, "Invalid Rate Window");
        require(isSupportedChainId(baseInput.l1ChainId), "Invalid L1 ChainId");
        require(baseInput.l1ERC20Address != address(0), "Invalid L1 ERC20 Address");
        require(baseInput.l2ChainIds.length > 0, "Invalid L2 ChainIds");
        for (uint256 i; i < baseInput.l2ChainIds.length; i++) {
            require(isSupportedChainId(baseInput.l2ChainIds[i]), "Invalid L2 ChainId");
        }
    }

    function _getIsL1() internal view returns (bool) {
        bool isL1 = block.chainid == baseInput.l1ChainId;
        bool isL2 = false;
        for (uint256 i; i < baseInput.l2ChainIds.length; i++) {
            isL2 = block.chainid == baseInput.l2ChainIds[i];
            if (isL2) {
                break;
            }
        }
        if (isL1 == isL2) {
            console.log("isL1: %s, isL2: %s, Got chainid: %d", isL1, isL2, block.chainid);
            revert("Invalid ChainId");
        }
        return isL1;
    }

    function _getDeploymentFilePath() internal view returns (string memory) {
        return string(
            abi.encodePacked(
                vm.projectRoot(),
                "/deployments/",
                baseInput.erc20Symbol,
                "-",
                vm.toString(baseInput.l1ChainId),
                "-",
                _version,
                ".json"
            )
        );
    }

    function _saveDeployment() internal {
        deployment.deployerAddress = msg.sender;
        bool found = false;
        for (uint256 i; i < deployment.chains.length; i++) {
            if (deployment.chains[i].chainId == block.chainid) {
                deployment.chains[i] = currentDeployment;
                found = true;
                break;
            }
        }
        if (!found) {
            deployment.chains.push(currentDeployment);
        }
        string memory json = vm.serializeAddress("deployment", "deployerAddress", deployment.deployerAddress);

        string memory chainsJson = "";

        for (uint256 i = 0; i < deployment.chains.length; i++) {
            string memory chainKey = string(abi.encodePacked("chains[", vm.toString(i), "]"));

            string memory chainJson = vm.serializeBool(chainKey, "isL1", deployment.chains[i].isL1);
            chainJson = vm.serializeUint(chainKey, "chainId", deployment.chains[i].chainId);
            chainJson = vm.serializeAddress(chainKey, "lzEndpoint", deployment.chains[i].lzEndpoint);
            chainJson = vm.serializeUint(chainKey, "lzEID", deployment.chains[i].lzEID);
            chainJson =
                vm.serializeAddress(chainKey, "multiChainDeployer", deployment.chains[i].multiChainDeployer);
            chainJson = vm.serializeAddress(chainKey, "erc20Address", deployment.chains[i].erc20Address);
            chainJson = vm.serializeAddress(chainKey, "oftAdapter", deployment.chains[i].oftAdapter);

            chainsJson = vm.serializeString("chains", vm.toString(deployment.chains[i].chainId), chainJson);
        }

        json = vm.serializeString("deployment", "chains", chainsJson);

        string memory filePath = _getDeploymentFilePath();
        vm.writeJson(json, filePath);
    }

    function _loadDeployment() internal {
        // Reset the deployment struct
        delete deployment;

        string memory filePath = _getDeploymentFilePath();

        if (!vm.isFile(filePath)) {
            return;
        }

        string memory json = vm.readFile(filePath);

        // Parse deployerAddress
        deployment.deployerAddress = vm.parseJsonAddress(json, ".deployerAddress");

        // Get the array of chain deployments
        string[] memory chainKeys = vm.parseJsonKeys(json, ".chains");
        ChainDeployment[] memory chains = new ChainDeployment[](chainKeys.length);

        // Loop through each chain and parse its fields
        for (uint256 i = 0; i < chainKeys.length; i++) {
            string memory chainKey = string(abi.encodePacked(".chains.", chainKeys[i]));

            chains[i].isL1 = vm.parseJsonBool(json, string(abi.encodePacked(chainKey, ".isL1")));
            chains[i].chainId = vm.parseJsonUint(json, string(abi.encodePacked(chainKey, ".chainId")));
            chains[i].lzEndpoint = vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".lzEndpoint")));
            chains[i].lzEID = uint32(vm.parseJsonUint(json, string(abi.encodePacked(chainKey, ".lzEID"))));
            chains[i].multiChainDeployer =
                vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".multiChainDeployer")));
            chains[i].erc20Address = vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".erc20Address")));
            chains[i].oftAdapter = vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".oftAdapter")));

            // Add the chain to the deployment
            deployment.chains.push(chains[i]);
        }
    }

    function _loadJson(string calldata _path) internal {
        string memory filePath = string(abi.encodePacked(vm.projectRoot(), _path));
        string memory json = vm.readFile(filePath);

        // Reset the baseInput struct
        delete baseInput;

        // Parse simple fields
        baseInput.erc20Name = vm.parseJsonString(json, ".erc20Name");
        baseInput.erc20Symbol = vm.parseJsonString(json, ".erc20Symbol");

        // Parse the L1Input struct
        baseInput.l1ChainId = vm.parseJsonUint(json, ".l1ChainId");
        baseInput.l1ERC20Address = vm.parseJsonAddress(json, ".l1ERC20Address");
        // Parse the L2ChainIds array
        baseInput.l2ChainIds = vm.parseJsonUintArray(json, ".l2ChainIds");

        // Parse RateLimitConfig struct
        baseInput.rateLimitConfig.limit = vm.parseJsonUint(json, ".rateLimitConfig.limit");
        baseInput.rateLimitConfig.window = vm.parseJsonUint(json, ".rateLimitConfig.window");
    }

    function createImmutableMultiChainDeployerSalt(address _deployerAddress)
        internal
        pure
        returns (bytes32 _salt)
    {
        _salt = createSalt(_deployerAddress, "ImmutableMultiChainDeployer");
    }

    function createL1YnOFTAdapterUpgradeableProxySalt(address _deployerAddress)
        internal
        pure
        returns (bytes32 _salt)
    {
        _salt = createSalt(_deployerAddress, "L1YnOFTAdapterUpgradeableProxy");
    }

    function createL1YnOFTAdapterUpgradeableSalt(address _deployerAddress) internal pure returns (bytes32 _salt) {
        _salt = createSalt(_deployerAddress, "L1YnOFTAdapterUpgradeable");
    }

    function createL2YnOFTAdapterUpgradeableProxySalt(address _deployerAddress)
        internal
        pure
        returns (bytes32 _salt)
    {
        _salt = createSalt(_deployerAddress, "L2YnOFTAdapterUpgradeableProxy");
    }

    function createL2YnOFTAdapterUpgradeableSalt(address _deployerAddress) internal pure returns (bytes32 _salt) {
        _salt = createSalt(_deployerAddress, "L2YnOFTAdapterUpgradeable");
    }

    function createL2YnERC20UpgradeableProxySalt(address _deployerAddress) internal pure returns (bytes32 _salt) {
        _salt = createSalt(_deployerAddress, "L2YnERC20UpgradeableProxy");
    }

    function createL2YnERC20UpgradeableSalt(address _deployerAddress) internal pure returns (bytes32 _salt) {
        _salt = createSalt(_deployerAddress, "L2YnERC20Upgradeable");
    }

    function createSalt(address _deployerAddress, string memory _label) internal pure returns (bytes32 _salt) {
        _salt = bytes32(
            abi.encodePacked(bytes20(_deployerAddress), bytes12(bytes32(keccak256(abi.encode(_label, _version)))))
        );
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function isContract(address _addr) public view returns (bool _isContract) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
