/* solhint-disable gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseData} from "./BaseData.s.sol";

import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";
import {L1YnOFTAdapterUpgradeable} from "src/L1YnOFTAdapterUpgradeable.sol";
import {ImmutableMultiChainDeployer} from "src/factory/ImmutableMultiChainDeployer.sol";

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Utils} from "script/Utils.sol";

import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

import {ILayerZeroEndpointV2} from
    "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {console} from "forge-std/console.sol";

import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";

import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";

import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";

import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

interface IOFTRateLimiter {
    function setRateLimits(RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs) external;
}

struct RateLimitConfig {
    uint256 limit;
    uint256 window;
}

struct BaseInput {
    string erc20Name;
    string erc20Symbol;
    uint8 erc20Decimals;
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
    address erc20ProxyAdmin;
    bool isL1;
    address lzEndpoint;
    uint32 lzEID;
    address multiChainDeployer;
    address oftAdapter;
    address oftAdapterProxyAdmin;
    address oftAdapterTimelock;
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

struct SendLibConfig {
    uint32 eid;
    address lib;
}

struct ReceiveLibConfig {
    uint32 eid;
    address lib;
}

contract BaseScript is BaseData, Utils {
    using Bytes32AddressLib for bytes32;
    using OptionsBuilder for bytes;

    BaseInput public baseInput;
    Deployment public deployment;
    ChainDeployment public currentDeployment;
    PredictedAddresses public predictions;
    string private constant VERSION = "v0.0.1";

    error InvalidDVN();

    uint32 internal constant CONFIG_TYPE_EXECUTOR = 1;
    uint32 internal constant CONFIG_TYPE_ULN = 2;
    uint32 internal constant DEFAULT_MAX_MESSAGE_SIZE = 10000;

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
        _loadInput(_inputPath, "");
    }

    function _loadInput(string calldata _inputPath, string memory _deploymentPath) internal {
        _loadJson(_inputPath);
        _validateInput();
        bool isL1 = _getIsL1();
        _loadDeployment(_deploymentPath);
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
            require(
                keccak256(bytes(IERC20(baseInput.l1ERC20Address).symbol()))
                    == keccak256(bytes(baseInput.erc20Symbol)),
                "Invalid ERC20 Symbol"
            );

            require(
                keccak256(bytes(IERC20(baseInput.l1ERC20Address).name())) == keccak256(bytes(baseInput.erc20Name)),
                "Invalid ERC20 Name"
            );

            require(
                IERC20(baseInput.l1ERC20Address).decimals() == baseInput.erc20Decimals, "Invalid ERC20 Decimals"
            );
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
        bytes memory proxyByteCode = hex"67363d3d37363d34f03d5260086018f3";

        bytes32 proxyByteCodeHash = keccak256(proxyByteCode);
        address proxy =
            keccak256(abi.encodePacked(bytes1(0xFF), _deployer, _salt, proxyByteCodeHash)).fromLast20Bytes();

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
                abi.encode(baseInput.l1ERC20Address, getData(baseInput.l1ChainId).LZ_ENDPOINT)
            );

            address predictedImplementation = vm.computeCreate2Address(implementationSalt, keccak256(implBytecode));

            bytes memory initializeData =
                abi.encodeWithSelector(L1YnOFTAdapterUpgradeable.initialize.selector, msg.sender);

            bytes32 timelockSalt = createL1YnOFTAdapterTimelockSalt(msg.sender);

            address predictedTimelock = _predictTimelockController(timelockSalt, baseInput.l1ChainId);

            bytes memory proxyBytecode = bytes.concat(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(predictedImplementation, predictedTimelock, initializeData)
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
    }

    function _validateInput() internal view {
        require(bytes(baseInput.erc20Name).length > 0, "Invalid ERC20 Name");
        require(bytes(baseInput.erc20Symbol).length > 0, "Invalid ERC20 Symbol");
        require(baseInput.erc20Decimals > 0, "Invalid ERC20 Decimals");
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
                VERSION,
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
            chainJson = vm.serializeAddress(chainKey, "erc20ProxyAdmin", deployment.chains[i].erc20ProxyAdmin);
            chainJson = vm.serializeAddress(chainKey, "oftAdapter", deployment.chains[i].oftAdapter);
            chainJson =
                vm.serializeAddress(chainKey, "oftAdapterProxyAdmin", deployment.chains[i].oftAdapterProxyAdmin);
            chainJson =
                vm.serializeAddress(chainKey, "oftAdapterTimelock", deployment.chains[i].oftAdapterTimelock);

            chainsJson = vm.serializeString("chains", vm.toString(deployment.chains[i].chainId), chainJson);
        }

        json = vm.serializeString("deployment", "chains", chainsJson);

        string memory filePath = _getDeploymentFilePath();
        vm.writeJson(json, filePath);
    }

    function _loadDeployment(string memory filePath) internal {
        // Reset the deployment struct
        delete deployment;

        if (keccak256(bytes(filePath)) == keccak256(bytes(""))) {
            filePath = _getDeploymentFilePath();
        }

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
            chains[i].erc20ProxyAdmin =
                vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".erc20ProxyAdmin")));
            chains[i].oftAdapter = vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".oftAdapter")));
            chains[i].oftAdapterProxyAdmin =
                vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".oftAdapterProxyAdmin")));
            chains[i].oftAdapterTimelock =
                vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".oftAdapterTimelock")));

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
        baseInput.erc20Decimals = uint8(vm.parseJsonUint(json, ".erc20Decimals"));

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
        view
        returns (bytes32 _salt)
    {
        _salt = createSalt(_deployerAddress, "MultiChainDeployer");
    }

    function createL1YnOFTAdapterUpgradeableProxySalt(address _deployerAddress)
        internal
        view
        returns (bytes32 _salt)
    {
        _salt = createSalt(_deployerAddress, "L1YnOFTAdapterProxy");
    }

    function createL1YnOFTAdapterUpgradeableSalt(address _deployerAddress) internal view returns (bytes32 _salt) {
        _salt = createSalt(_deployerAddress, "L1YnOFTAdapter");
    }

    function createL2YnOFTAdapterUpgradeableProxySalt(address _deployerAddress)
        internal
        view
        returns (bytes32 _salt)
    {
        _salt = createSalt(_deployerAddress, "L2YnOFTAdapterProxy");
    }

    function createL2YnOFTAdapterUpgradeableSalt(address _deployerAddress) internal view returns (bytes32 _salt) {
        _salt = createSalt(_deployerAddress, "L2YnOFTAdapter");
    }

    function createL2YnERC20UpgradeableProxySalt(address _deployerAddress) internal view returns (bytes32 _salt) {
        _salt = createSalt(_deployerAddress, "L2YnERC20Proxy");
    }

    function createL2YnERC20UpgradeableSalt(address _deployerAddress) internal view returns (bytes32 _salt) {
        _salt = createSalt(_deployerAddress, "L2YnERC20");
    }

    function createL1YnOFTAdapterTimelockSalt(address _deployerAddress) internal view returns (bytes32 _salt) {
        _salt = createSalt(_deployerAddress, "L1YnOFTTimelock");
    }

    function createL2YnOFTAdapterTimelockSalt(address _deployerAddress) internal view returns (bytes32 _salt) {
        _salt = createSalt(_deployerAddress, "L2YnOFTTimelock");
    }

    function createSalt(address _deployerAddress, string memory _label) internal view returns (bytes32 _salt) {
        require(bytes(baseInput.erc20Symbol).length > 0, "Invalid ERC20 Symbol");

        _salt = bytes32(
            abi.encodePacked(
                bytes20(_deployerAddress),
                bytes12(bytes32(keccak256(abi.encode(_label, baseInput.erc20Symbol, VERSION))))
            )
        );
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function isContract(address _addr) public view returns (bool _isContract) {
        uint32 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function _predictTimelockController(
        bytes32 timelockSalt,
        uint256 chainId
    )
        internal
        virtual
        returns (address)
    {
        address admin = getData(chainId).PROXY_ADMIN;

        address[] memory proposers = new address[](1);
        proposers[0] = admin;

        address[] memory executors = new address[](1);
        executors[0] = admin;

        uint256 minDelay = getMinDelay(chainId);

        bytes memory timelockBytecode =
            bytes.concat(type(TimelockController).creationCode, abi.encode(minDelay, proposers, executors, admin));

        address predictedTimelock = vm.computeCreate2Address(timelockSalt, keccak256(timelockBytecode));

        return predictedTimelock;
    }

    function _deployTimelockController(
        bytes32 timelockSalt,
        uint256 chainId
    )
        internal
        virtual
        returns (address timelock)
    {
        address admin = getData(chainId).PROXY_ADMIN;

        address[] memory proposers = new address[](1);
        proposers[0] = admin;

        address[] memory executors = new address[](1);
        executors[0] = admin;

        uint256 minDelay = getMinDelay(chainId);

        timelock = address(new TimelockController{salt: timelockSalt}(minDelay, proposers, executors, admin));
    }

    function configureRateLimits() internal {
        console.log("Configuring rate limits...");

        IOFTRateLimiter oftAdapter = IOFTRateLimiter(payable(currentDeployment.oftAdapter));
        vm.startBroadcast();
        oftAdapter.setRateLimits(_getRateLimitConfigs());
        console.log("Set rate limits");
        vm.stopBroadcast();
    }

    function configurePeers(uint256[] memory dstChainIds) internal {
        console.log("Configuring peers...");

        OFTAdapterUpgradeable oftAdapter = OFTAdapterUpgradeable(currentDeployment.oftAdapter);
        for (uint256 i = 0; i < dstChainIds.length; i++) {
            uint256 chainId = dstChainIds[i];
            uint32 eid = getEID(chainId);
            address adapter = chainId == baseInput.l1ChainId ? predictions.l1OFTAdapter : predictions.l2OFTAdapter;
            bytes32 adapterBytes32 = addressToBytes32(adapter);
            if (oftAdapter.peers(eid) == adapterBytes32) {
                console.log("Already set peer for chainid %d", chainId);
                continue;
            }

            vm.startBroadcast();
            oftAdapter.setPeer(eid, adapterBytes32);
            console.log("Set peer for chainid %d", chainId);
            vm.stopBroadcast();
        }
    }

    function configureSendLibs(uint256[] memory dstChainIds) internal {
        console.log("Configuring send libs...");
        ILayerZeroEndpointV2 lzEndpoint = ILayerZeroEndpointV2(getData(block.chainid).LZ_ENDPOINT);

        for (uint256 i = 0; i < dstChainIds.length; i++) {
            uint256 chainId = dstChainIds[i];
            uint32 eid = getEID(chainId);

            if (lzEndpoint.getSendLibrary(currentDeployment.oftAdapter, eid) == getData(block.chainid).LZ_SEND_LIB)
            {
                console.log("Already set send library for chainid %d", chainId);
                continue;
            }
            vm.startBroadcast();
            lzEndpoint.setSendLibrary(currentDeployment.oftAdapter, eid, getData(block.chainid).LZ_SEND_LIB);
            console.log("Set send library for chainid %d", chainId);
            vm.stopBroadcast();
        }
    }

    function configureReceiveLibs(uint256[] memory dstChainIds) internal {
        console.log("Configuring receive libs...");
        ILayerZeroEndpointV2 lzEndpoint = ILayerZeroEndpointV2(getData(block.chainid).LZ_ENDPOINT);

        for (uint256 i = 0; i < dstChainIds.length; i++) {
            uint256 chainId = dstChainIds[i];
            uint32 eid = getEID(chainId);
            (address lib, bool isDefault) = lzEndpoint.getReceiveLibrary(currentDeployment.oftAdapter, eid);
            if (lib == getData(block.chainid).LZ_RECEIVE_LIB && isDefault == false) {
                console.log("Already set receive library for chainid %d", chainId);
                continue;
            }

            vm.startBroadcast();
            lzEndpoint.setReceiveLibrary(
                currentDeployment.oftAdapter, eid, getData(block.chainid).LZ_RECEIVE_LIB, 0
            );
            console.log("Set receive library for chainid %d", chainId);
            vm.stopBroadcast();
        }
    }

    function configureEnforcedOptions(uint256[] memory dstChainIds) internal {
        console.log("Configuring enforced options...");

        OFTAdapterUpgradeable oftAdapter = OFTAdapterUpgradeable(currentDeployment.oftAdapter);
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](dstChainIds.length * 2);
        for (uint256 i = 0; i < dstChainIds.length; i++) {
            uint256 chainId = dstChainIds[i];
            uint32 dstEid = getEID(chainId);
            enforcedOptions[2 * i] = EnforcedOptionParam({
                eid: dstEid,
                msgType: 1,
                options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(170_000, 0)
            });
            enforcedOptions[2 * i + 1] = EnforcedOptionParam({
                eid: dstEid,
                msgType: 2,
                options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(170_000, 0).addExecutorLzComposeOption(
                    0, 170_000, 0
                )
            });
        }

        vm.startBroadcast();
        oftAdapter.setEnforcedOptions(enforcedOptions);
        console.log("Set enforced options");
        vm.stopBroadcast();
    }

    function configureDVNs(uint256[] memory dstChainIds) internal {
        console.log("Configuring DVNs...");

        Data storage data = getData(block.chainid);
        ILayerZeroEndpointV2 lzEndpoint = ILayerZeroEndpointV2(data.LZ_ENDPOINT);

        bool isTestnet = isTestnetChainId(block.chainid);
        uint64 confirmations = isTestnet ? 8 : 32;
        uint8 requiredDVNCount = isTestnet ? 1 : 2;

        for (uint256 i = 0; i < dstChainIds.length; i++) {
            uint256 chainId = dstChainIds[i];
            uint32 dstEid = getEID(chainId);
            address[] memory requiredDVNs = new address[](isTestnet ? 1 : 2);

            if (isTestnet) {
                requiredDVNs[0] = data.LZ_DVN;
            } else {
                if (data.LZ_DVN > data.NETHERMIND_DVN) {
                    requiredDVNs[0] = data.NETHERMIND_DVN;
                    requiredDVNs[1] = data.LZ_DVN;
                } else {
                    requiredDVNs[0] = data.LZ_DVN;
                    requiredDVNs[1] = data.NETHERMIND_DVN;
                }
            }

            UlnConfig memory ulnConfig = UlnConfig({
                confirmations: confirmations,
                requiredDVNCount: requiredDVNCount,
                optionalDVNCount: 0,
                optionalDVNThreshold: 0,
                requiredDVNs: requiredDVNs,
                optionalDVNs: new address[](0)
            });

            SetConfigParam[] memory params = new SetConfigParam[](1);
            params[0] = SetConfigParam(dstEid, CONFIG_TYPE_ULN, abi.encode(ulnConfig));
            vm.startBroadcast();
            console.log("SENDER", msg.sender);
            lzEndpoint.setConfig(currentDeployment.oftAdapter, data.LZ_SEND_LIB, params);
            lzEndpoint.setConfig(currentDeployment.oftAdapter, data.LZ_RECEIVE_LIB, params);
            vm.stopBroadcast();
            console.log("Set DVNs for chainid %d", chainId);
        }
    }

    function configureExecutor(uint256[] memory dstChainIds) internal {
        console.log("Configuring executor...");

        Data storage data = getData(block.chainid);
        ILayerZeroEndpointV2 lzEndpoint = ILayerZeroEndpointV2(data.LZ_ENDPOINT);

        for (uint256 i = 0; i < dstChainIds.length; i++) {
            uint256 chainId = dstChainIds[i];
            uint32 dstEid = getEID(chainId);

            ExecutorConfig memory executorConfig =
                ExecutorConfig({maxMessageSize: DEFAULT_MAX_MESSAGE_SIZE, executor: data.LZ_EXECUTOR});

            SetConfigParam[] memory params = new SetConfigParam[](1);
            params[0] = SetConfigParam(dstEid, CONFIG_TYPE_EXECUTOR, abi.encode(executorConfig));
            vm.startBroadcast();
            lzEndpoint.setConfig(currentDeployment.oftAdapter, data.LZ_SEND_LIB, params);
            vm.stopBroadcast();

            console.log("Set executor for chainid %d", chainId);
        }
    }
}
