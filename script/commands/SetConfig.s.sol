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

contract CreateConfigTX is BaseData, BaseScript {
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

contract CreateBatchConfigTX is CreateConfigTX, BatchScript {
    function run(string memory inputPath, string memory deploymentPath) external {
        uint256[] memory dstChainIds = _getChainIds(inputPath, deploymentPath);

        address adapter;
        bytes memory encodedTx;

        for (uint256 i = 0; i < dstChainIds.length; i++) {
            (adapter, encodedTx) = getConfigureRateLimitsTX();
            _addToBatch(adapter, 0, encodedTx);

            (adapter, encodedTx) = getConfigurePeersTX(dstChainIds[i]);
            _addToBatch(adapter, 0, encodedTx);

            (adapter, encodedTx) = getConfigureSendLibTX(dstChainIds[i]);
            _addToBatch(adapter, 0, encodedTx);

            (adapter, encodedTx) = getConfigureReceiveLibTX(dstChainIds[i]);
            _addToBatch(adapter, 0, encodedTx);

            (adapter, encodedTx) = getConfigureEnforcedOptionsTX(dstChainIds[i]);
            _addToBatch(adapter, 0, encodedTx);

            bytes memory sendEncodedTx;
            bytes memory receiveEncodedTX;
            (adapter, sendEncodedTx, receiveEncodedTX) = getConfigureDVNsTX(dstChainIds[i]);
            _addToBatch(adapter, 0, sendEncodedTx);
            _addToBatch(adapter, 0, receiveEncodedTX);

            (adapter, encodedTx) = getConfigureExecutorTX(dstChainIds[i]);
            _addToBatch(adapter, 0, encodedTx);
        }

        console.log("Encoded Txns: ");
        for (uint256 i = 0; i < encodedTxns.length; i++) {
            console.logBytes(encodedTxns[i]);
        }
    }

    function _addToBatch(address adapter, bytes memory encodedTx) internal {
        if (adapter != address(0) && encodedTx.length > 0) {
            addToBatch(adapter, 0, encodedTx);
        }
    }
}
