/* solhint-disable gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseData} from "./BaseData.s.sol";
import {CREATE3Script} from "./CREATE3Script.sol";
import {Utils} from "./Utils.sol";

import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {CREATE3Script} from "script/CREATE3Script.sol";
import {Utils} from "script/Utils.sol";

import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

import {console} from "forge-std/console.sol";

import {ILayerZeroEndpointV2} from
    "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IMessageLibManager} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {IOAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {console} from "forge-std/console.sol";

import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";

import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";

import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";

interface IOFTRateLimiter {
    function setRateLimits(RateLimiter.RateLimitConfig[] calldata _rateLimitConfigs) external;
    function rateLimits(uint32 _eid) external view returns (RateLimiter.RateLimit memory);
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
}

struct ChainDeployment {
    uint256 chainId;
    address erc20Address;
    address erc20ProxyAdmin;
    address erc20Implementation;
    bool isL1;
    address lzEndpoint;
    uint32 lzEID;
    address oftAdapter;
    address oftAdapterProxyAdmin;
    address oftAdapterImplementation;
    address oftAdapterTimelock;
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

contract BaseScript is BaseData, CREATE3Script, Utils {
    using Bytes32AddressLib for bytes32;
    using OptionsBuilder for bytes;

    BaseInput public baseInput;
    Deployment public deployment;
    ChainDeployment public currentDeployment;
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
        require(
            deployment.deployerAddress == address(0) || deployment.deployerAddress == msg.sender,
            "Invalid Deployer Address"
        );
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
            chainJson = vm.serializeAddress(chainKey, "erc20Address", deployment.chains[i].erc20Address);
            chainJson = vm.serializeAddress(chainKey, "erc20ProxyAdmin", deployment.chains[i].erc20ProxyAdmin);
            chainJson =
                vm.serializeAddress(chainKey, "erc20Implementation", deployment.chains[i].erc20Implementation);
            chainJson = vm.serializeAddress(chainKey, "oftAdapter", deployment.chains[i].oftAdapter);
            chainJson =
                vm.serializeAddress(chainKey, "oftAdapterProxyAdmin", deployment.chains[i].oftAdapterProxyAdmin);
            chainJson = vm.serializeAddress(
                chainKey, "oftAdapterImplementation", deployment.chains[i].oftAdapterImplementation
            );
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
            chains[i].erc20Address = vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".erc20Address")));
            chains[i].erc20ProxyAdmin =
                vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".erc20ProxyAdmin")));
            chains[i].erc20Implementation =
                vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".erc20Implementation")));
            chains[i].oftAdapter = vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".oftAdapter")));
            chains[i].oftAdapterProxyAdmin =
                vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".oftAdapterProxyAdmin")));
            chains[i].oftAdapterImplementation =
                vm.parseJsonAddress(json, string(abi.encodePacked(chainKey, ".oftAdapterImplementation")));
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

    function createOFTAdapterProxySalt() internal view returns (bytes32 _salt) {
        _salt = createSalt("OFTAdapterProxy");
    }

    function createOFTAdapterImplementationSalt() internal view returns (bytes32 _salt) {
        _salt = createSalt("OFTAdapterImplementation");
    }

    function createERC20ProxySalt() internal view returns (bytes32 _salt) {
        _salt = createSalt("ERC20Proxy");
    }

    function createERC20ImplementationSalt() internal view returns (bytes32 _salt) {
        _salt = createSalt("ERC20Implementation");
    }

    function createTimelockSalt() internal view returns (bytes32 _salt) {
        _salt = createSalt("OFTTimelock");
    }

    function createSalt(string memory _label) internal view returns (bytes32 _salt) {
        require(bytes(baseInput.erc20Symbol).length > 0, "Invalid ERC20 Symbol");

        _salt = bytes32(keccak256(abi.encode(_label, baseInput.erc20Symbol, VERSION)));
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

    function findChainDeployment(uint256 chainId) internal view returns (ChainDeployment memory) {
        for (uint256 i = 0; i < deployment.chains.length; i++) {
            if (deployment.chains[i].chainId == chainId) {
                return deployment.chains[i];
            }
        }
        revert(string.concat("Deployment for chain ", vm.toString(chainId), " not found"));
    }

    function configureRateLimits() internal {
        console.log("Configuring rate limits...");

        IOFTRateLimiter oftAdapter = IOFTRateLimiter(payable(currentDeployment.oftAdapter));
        vm.startBroadcast();
        oftAdapter.setRateLimits(_getRateLimitConfigs());
        vm.stopBroadcast();
    }

    function getConfigureRateLimitsTX()
        internal
        view
        returns (address oftAdapterAddress, bytes memory encodedRateLimitConfigs)
    {
        RateLimiter.RateLimitConfig[] memory rateLimitConfigs = _getRateLimitConfigs();
        RateLimiter.RateLimitConfig[] memory newRateLimitConfigs =
            new RateLimiter.RateLimitConfig[](rateLimitConfigs.length);
        uint256 uniqueLimits = 0;
        RateLimiter.RateLimit memory currentLimit;
        // check for existing rate limits
        for (uint256 i = 0; i < rateLimitConfigs.length; i++) {
            currentLimit = _getCurrentRateLimit(rateLimitConfigs[i].dstEid);
            if (
                currentLimit.limit != rateLimitConfigs[i].limit
                    || currentLimit.window != rateLimitConfigs[i].window
            ) {
                newRateLimitConfigs[uniqueLimits] = rateLimitConfigs[i];
                uniqueLimits++;
            }
        }

        if (uniqueLimits == 0) {
            return (address(0), "");
        }

        RateLimiter.RateLimitConfig[] memory finalRateLimitConfigs =
            new RateLimiter.RateLimitConfig[](uniqueLimits);
        // copy new rate limits to final rate limits
        for (uint256 i = 0; i < uniqueLimits; i++) {
            finalRateLimitConfigs[i] = newRateLimitConfigs[i];
        }
        encodedRateLimitConfigs =
            abi.encodeWithSelector(IOFTRateLimiter.setRateLimits.selector, finalRateLimitConfigs);
    }

    function _getCurrentRateLimit(uint32 _eid) internal view returns (RateLimiter.RateLimit memory) {
        IOFTRateLimiter rateLimiter = IOFTRateLimiter(currentDeployment.oftAdapter);

        try rateLimiter.rateLimits(_eid) returns (RateLimiter.RateLimit memory rateLimit) {
            console.log("Rate limit found for eid %d", _eid);
            return rateLimit;
        } catch {
            console.log("No rate limit found for eid %d", _eid);
            return RateLimiter.RateLimit({limit: 0, window: 0, amountInFlight: 0, lastUpdated: 0});
        }
    }

    function configurePeers(uint256[] memory dstChainIds) internal {
        console.log("Configuring peers...");

        OFTAdapterUpgradeable oftAdapter = OFTAdapterUpgradeable(currentDeployment.oftAdapter);
        for (uint256 i = 0; i < dstChainIds.length; i++) {
            uint256 chainId = dstChainIds[i];
            uint32 eid = getEID(chainId);

            ChainDeployment memory chainDeployment = findChainDeployment(chainId);
            address adapter = chainDeployment.oftAdapter;
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

    function getConfigurePeersTX(uint256 chainId)
        internal
        view
        returns (address oftAdapter, bytes memory encodedPeersTX)
    {
        uint32 eid = getEID(chainId);
        address adapter = chainId == baseInput.l1ChainId ? predictions.l1OFTAdapter : predictions.l2OFTAdapter;
        bytes32 adapterBytes32 = addressToBytes32(adapter);

        oftAdapter = currentDeployment.oftAdapter;
        if (OFTAdapterUpgradeable(oftAdapter).peers(eid) == adapterBytes32) {
            console.log("Already set peer for chainid %d", chainId);
            oftAdapter = address(0);
            encodedPeersTX = "";
        } else {
            encodedPeersTX = abi.encodeWithSelector(IOAppCore.setPeer.selector, eid, adapterBytes32);
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

    function getConfigureSendLibTX(uint256 chainId)
        internal
        view
        returns (address lzEndpoint, bytes memory encodedSendLibTX)
    {
        uint32 eid = getEID(chainId);
        lzEndpoint = getData(block.chainid).LZ_ENDPOINT;
        if (
            ILayerZeroEndpointV2(lzEndpoint).getSendLibrary(currentDeployment.oftAdapter, eid)
                == getData(block.chainid).LZ_SEND_LIB
        ) {
            console.log("Already set send library for chainid %d", chainId);
            lzEndpoint = address(0);
            encodedSendLibTX = "";
        } else {
            encodedSendLibTX = abi.encodeWithSelector(
                IMessageLibManager.setSendLibrary.selector,
                currentDeployment.oftAdapter,
                eid,
                getData(block.chainid).LZ_SEND_LIB
            );
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

    function getConfigureReceiveLibTX(uint256 chainId)
        internal
        view
        returns (address lzEndpoint, bytes memory encodedReceiveLibTX)
    {
        uint32 eid = getEID(chainId);
        lzEndpoint = getData(block.chainid).LZ_ENDPOINT;
        (address lib, bool isDefault) =
            ILayerZeroEndpointV2(lzEndpoint).getReceiveLibrary(currentDeployment.oftAdapter, eid);
        if (lib == getData(block.chainid).LZ_RECEIVE_LIB && isDefault == false) {
            console.log("Already set receive library for chainid %d", chainId);
            lzEndpoint = address(0);
            encodedReceiveLibTX = "";
        }
        encodedReceiveLibTX = abi.encodeWithSelector(
            IMessageLibManager.setReceiveLibrary.selector,
            currentDeployment.oftAdapter,
            eid,
            getData(block.chainid).LZ_RECEIVE_LIB,
            0
        );
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

    function getConfigureEnforcedOptionsTX(uint256 dstChainId)
        internal
        view
        returns (address oftAdapter, bytes memory encodedEnforcedOptions)
    {
        oftAdapter = currentDeployment.oftAdapter;

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);

        uint32 dstEid = getEID(dstChainId);
        enforcedOptions[0] = EnforcedOptionParam({
            eid: dstEid,
            msgType: 1,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(170_000, 0)
        });

        enforcedOptions[1] = EnforcedOptionParam({
            eid: dstEid,
            msgType: 2,
            options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(170_000, 0).addExecutorLzComposeOption(
                0, 170_000, 0
            )
        });

        encodedEnforcedOptions =
            abi.encodeWithSelector(IOAppOptionsType3.setEnforcedOptions.selector, enforcedOptions);
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

    function getConfigureDVNsTX(uint256 dstChainId)
        internal
        view
        returns (address lzEndpoint, bytes memory encodedSendTx, bytes memory encodedReceiveTx)
    {
        Data storage data = getData(block.chainid);
        uint32 dstEid = getEID(dstChainId);
        bool isTestnet = isTestnetChainId(block.chainid);

        address[] memory requiredDVNs = new address[](isTestnet ? 1 : 2);
        uint64 confirmations = isTestnet ? 8 : 32;
        uint8 requiredDVNCount = isTestnet ? 1 : 2;

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

        lzEndpoint = getData(block.chainid).LZ_ENDPOINT;
        encodedSendTx = abi.encodeWithSelector(
            IMessageLibManager.setConfig.selector, currentDeployment.oftAdapter, data.LZ_SEND_LIB, params
        );
        encodedReceiveTx = abi.encodeWithSelector(
            IMessageLibManager.setConfig.selector, currentDeployment.oftAdapter, data.LZ_RECEIVE_LIB, params
        );
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

    function getConfigureExecutorTX(uint256 dstChainId)
        internal
        view
        returns (address lzEndpoint, bytes memory encodedExecutorTx)
    {
        Data storage data = getData(block.chainid);
        uint32 dstEid = getEID(dstChainId);
        ExecutorConfig memory executorConfig =
            ExecutorConfig({maxMessageSize: DEFAULT_MAX_MESSAGE_SIZE, executor: data.LZ_EXECUTOR});

        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam(dstEid, CONFIG_TYPE_EXECUTOR, abi.encode(executorConfig));

        lzEndpoint = getData(block.chainid).LZ_ENDPOINT;
        encodedExecutorTx = abi.encodeWithSelector(
            IMessageLibManager.setConfig.selector, currentDeployment.oftAdapter, data.LZ_SEND_LIB, params
        );
    }
}
