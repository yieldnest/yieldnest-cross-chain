/* solhint-disable gas-custom-errors, check-send-result */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {L2YnOFTAdapterUpgradeable} from "../../src/L2YnOFTAdapterUpgradeable.sol";
import {BaseData} from "../BaseData.s.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {BatchScript} from "../BatchScript.s.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {ILayerZeroEndpointV2} from
    "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IMessageLibManager} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";

import {console} from "forge-std/console.sol";

contract CreateDVNConfigTX is BaseData, BaseScript {
    using OptionsBuilder for bytes;

    L2YnOFTAdapterUpgradeable public l2OFTAdapter;

    function _getChainIds(
        string memory inputPath,
        string memory deploymentPath
    )
        internal
        returns (uint256[] memory)
    {
        uint256 sourceChainId = block.chainid;

        // Load deployment config
        string memory json = vm.readFile(deploymentPath);

        __loadJson(inputPath);

        address oftAdapter = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapter")), (address)
        );
        l2OFTAdapter = L2YnOFTAdapterUpgradeable(oftAdapter);

        require(isSupportedChainId(sourceChainId), "Unsupported destination chain ID");

        uint32 destinationEid = getEID(sourceChainId);

        console.log("Chain ID: %s", block.chainid);
        console.log("Sender: %s", msg.sender);
        console.log("Destination Chain ID: %s", sourceChainId);
        console.log("Destination EID: %s", destinationEid);

        uint256[] memory dstChainIds = baseInput.l2ChainIds;

        for (uint256 i = 0; i < dstChainIds.length; i++) {
            if (dstChainIds[i] == block.chainid) {
                dstChainIds[i] = baseInput.l1ChainId;
            }
        }

        return dstChainIds;
    }

    function __getConfigParams(uint256[] memory dstChainIds)
        internal
        view
        returns (SetConfigParam[] memory configParams)
    {
        console.log("Creating config params...");

        Data storage data = getData(block.chainid);

        bool isTestnet = isTestnetChainId(block.chainid);
        uint64 confirmations = isTestnet ? 8 : 32;
        uint8 requiredDVNCount = isTestnet ? 1 : 2;

        SetConfigParam[] memory params = new SetConfigParam[](dstChainIds.length);

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

            params[i] = SetConfigParam(dstEid, CONFIG_TYPE_ULN, abi.encode(ulnConfig));
        }

        return params;
    }

    function __loadJson(string memory _path) private {
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
}

contract ConfigureDVNs is CreateDVNConfigTX {
    function run(string memory deploymentPath, string memory inputPath) external {
        if (l2OFTAdapter.owner() == msg.sender) {
            uint256[] memory dstChainIds = _getChainIds(inputPath, deploymentPath);

            __configureDVNs(dstChainIds);
        }
    }

    function __configureDVNs(uint256[] memory dstChainIds) internal {
        console.log("Configuring DVNs...");

        Data storage data = getData(block.chainid);
        ILayerZeroEndpointV2 lzEndpoint = ILayerZeroEndpointV2(data.LZ_ENDPOINT);

        SetConfigParam[] memory params = __getConfigParams(dstChainIds);
        SetConfigParam[] memory tempParam = new SetConfigParam[](1);

        for (uint256 i = 0; i < params.length; i++) {
            tempParam[0] = params[i];
            vm.startBroadcast();
            console.log("SENDER", msg.sender);
            lzEndpoint.setConfig(address(l2OFTAdapter), data.LZ_SEND_LIB, tempParam);
            lzEndpoint.setConfig(address(l2OFTAdapter), data.LZ_RECEIVE_LIB, tempParam);
            vm.stopBroadcast();
            console.log("Set DVNs for dstChainId %d", tempParam[0].eid);
        }
    }
}

contract CreateBatchDVNTX is CreateDVNConfigTX, BatchScript {
    function run(string memory deploymentPath, string memory inputPath) external {
        uint256[] memory dstChainIds = _getChainIds(inputPath, deploymentPath);
        bytes[] memory encodedTransactions = createBatchDVNTX(dstChainIds);

        console.log("Encoded Txns: ");
        for (uint256 i = 0; i < encodedTransactions.length; i++) {
            console.logBytes(encodedTransactions[i]);
        }
    }

    function createBatchDVNTX(uint256[] memory dstChainIds) internal returns (bytes[] memory) {
        console.log("Configuring DVNs...");

        Data storage data = getData(block.chainid);

        SetConfigParam[] memory params = __getConfigParams(dstChainIds);
        SetConfigParam[] memory tempParam = new SetConfigParam[](1);

        for (uint256 i = 0; i < params.length; i++) {
            tempParam[0] = params[i];
            bytes memory encodedSendTx =
                abi.encodeWithSelector(IMessageLibManager.setConfig.selector, data.LZ_SEND_LIB, tempParam);
            bytes memory encodedReceiveTx =
                abi.encodeWithSelector(IMessageLibManager.setConfig.selector, data.LZ_RECEIVE_LIB, tempParam);

            addToBatch(address(data.LZ_ENDPOINT), 0, encodedSendTx);
            addToBatch(address(data.LZ_ENDPOINT), 0, encodedReceiveTx);

            console.log("Encoded Send Tx added for dstChainId: ", tempParam[0].eid);
        }

        return encodedTxns;
    }
}
