/* solhint-disable gas-custom-errors, check-send-result */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {L2YnOFTAdapterUpgradeable} from "../../src/L2YnOFTAdapterUpgradeable.sol";
import {BaseData} from "../BaseData.s.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {ILayerZeroEndpointV2} from
    "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IOFT, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {console} from "forge-std/console.sol";

/**
 * @notice This script bridges ynETHx tokens between chains using LayerZero OFT protocol
 *
 * @dev How it works:
 * 1. User provides destination chain ID via prompt
 * 2. If on base chain (L1):
 *    - Wraps ETH to WETH by sending ETH to WETH contract
 * 3. Bridges tokens via OFT adapter's sendFrom()
 *
 * Usage:
 * ```
 * forge script script/commands/SetConfig.s.sol:SetConfig --rpc-url <RPC_URL> --broadcast
 * ```
 */
contract ConfigureDVNs is BaseData, BaseScript {
    using OptionsBuilder for bytes;

    L2YnOFTAdapterUpgradeable l2OFTAdapter;

    // Amount to bridge
    uint256 public constant BRIDGE_AMOUNT = 0.00001 ether;

    function run() external {
        uint256 sourceChainId = block.chainid;
        uint256 baseChainId = 56; //bsc

        // Load deployment config
        string memory json =
            vm.readFile(string.concat("deployments/ynBTCk-", vm.toString(baseChainId), "-v0.0.2.json"));

        __loadJson(string.concat("/script/inputs/bsc-ynBTCk.json"));

        address oftAdapter = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapter")), (address)
        );
        l2OFTAdapter = L2YnOFTAdapterUpgradeable(oftAdapter);

        require(isSupportedChainId(sourceChainId), "Unsupported destination chain ID");

        uint32 destinationEid = getEID(sourceChainId);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address sender = vm.addr(deployerPrivateKey);

        address refundAddress = sender;

        console.log("Chain ID: %s", block.chainid);
        console.log("Sender: %s", sender);
        console.log("Destination Chain ID: %s", sourceChainId);
        console.log("Destination EID: %s", destinationEid);

        if (l2OFTAdapter.owner() == sender) {
            uint256[] memory dstChainIds = baseInput.l2ChainIds;
            for (uint256 i = 0; i < dstChainIds.length; i++) {
                if (dstChainIds[i] == block.chainid) {
                    dstChainIds[i] = baseInput.l1ChainId;
                }
            }

            __configureDVNs(dstChainIds);
        }
    }

    function __configureDVNs(uint256[] memory dstChainIds) internal {
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
            lzEndpoint.setConfig(address(l2OFTAdapter), data.LZ_SEND_LIB, params);
            lzEndpoint.setConfig(address(l2OFTAdapter), data.LZ_RECEIVE_LIB, params);
            vm.stopBroadcast();
            console.log("Set DVNs for chainid %d", chainId);
        }
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
