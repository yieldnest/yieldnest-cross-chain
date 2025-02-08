/* solhint-disable no-console, gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript, PeerConfig, ReceiveLibConfig, SendLibConfig} from "./BaseScript.s.sol";
import {BatchScript} from "./BatchScript.s.sol";

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";

import {IOAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {console} from "forge-std/console.sol";

// forge script script/VerifyL1OFTAdapter.s.sol:DeployL1OFTAdapter \
// --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
// --account ${deployerAccountName} --sender ${deployer}

contract VerifyL1OFTAdapter is BaseScript, BatchScript {
    L1YnOFTAdapterUpgradeable public l1OFTAdapter;

    RateLimiter.RateLimitConfig[] public newRateLimitConfigs;
    PeerConfig[] public newPeers;
    SendLibConfig[] public newSendLibs;
    ReceiveLibConfig[] public newReceiveLibs;

    function run(string calldata _jsonPath) public isBatch(getData(block.chainid).OFT_OWNER) {
        _loadInput(_jsonPath);

        require(currentDeployment.isL1 == true, "Must be L1 deployment");

        if (!isContract(currentDeployment.oftAdapter)) {
            revert("L1 OFT Adapter not deployed");
        }

        require(address(currentDeployment.oftAdapter) == predictions.l1OFTAdapter, "Predicted address mismatch");

        l1OFTAdapter = L1YnOFTAdapterUpgradeable(currentDeployment.oftAdapter);

        if (l1OFTAdapter.owner() != getData(block.chainid).OFT_OWNER) {
            revert("L1 OFT Adapter ownership not transferred");
        }

        address proxyAdmin = getTransparentUpgradeableProxyAdminAddress(address(l1OFTAdapter));
        if (proxyAdmin != currentDeployment.oftAdapterProxyAdmin) {
            revert("L1 OFT Adapter proxy admin is not correct");
        }
        address proxyAdminOwner = ProxyAdmin(proxyAdmin).owner();
        if (proxyAdminOwner != currentDeployment.oftAdapterTimelock) {
            revert("L1 OFT Adapter timelock is not correct");
        }
        TimelockController timelock = TimelockController(payable(currentDeployment.oftAdapterTimelock));
        if (!timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), getData(block.chainid).PROXY_ADMIN)) {
            revert("L1 OFT Adapter timelock admin is not correct");
        }

        uint256[] memory chainIds = new uint256[](baseInput.l2ChainIds.length + 1);
        for (uint256 i = 0; i < baseInput.l2ChainIds.length; i++) {
            chainIds[i] = baseInput.l2ChainIds[i];
        }
        chainIds[baseInput.l2ChainIds.length] = baseInput.l1ChainId;

        bool needsUpdate = false;

        ILayerZeroEndpointV2 lzEndpoint = ILayerZeroEndpointV2(getData(block.chainid).LZ_ENDPOINT);

        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 chainId = chainIds[i];
            uint32 eid = getEID(chainId);
            (,, uint256 limit, uint256 window) = l1OFTAdapter.rateLimits(eid);
            if (limit != baseInput.rateLimitConfig.limit || window != baseInput.rateLimitConfig.window) {
                needsUpdate = true;
                newRateLimitConfigs.push(
                    RateLimiter.RateLimitConfig(
                        eid, baseInput.rateLimitConfig.limit, baseInput.rateLimitConfig.window
                    )
                );
            }
            if (chainId == block.chainid) {
                continue;
            }
            address adapter = predictions.l2OFTAdapter;
            bytes32 adapterBytes32 = addressToBytes32(adapter);
            if (l1OFTAdapter.peers(eid) != adapterBytes32) {
                needsUpdate = true;
                newPeers.push(PeerConfig(eid, adapter));
            }
            if (lzEndpoint.getSendLibrary(address(l1OFTAdapter), eid) != getData(block.chainid).LZ_SEND_LIB) {
                needsUpdate = true;
                newSendLibs.push(SendLibConfig(eid, getData(block.chainid).LZ_SEND_LIB));
            }
            (address lib, bool isDefault) = lzEndpoint.getReceiveLibrary(address(l1OFTAdapter), eid);
            if (lib != getData(block.chainid).LZ_RECEIVE_LIB || isDefault == false) {
                needsUpdate = true;
                newReceiveLibs.push(ReceiveLibConfig(eid, getData(block.chainid).LZ_RECEIVE_LIB));
            }
        }

        if (needsUpdate) {
            console.log("");
            console.log("Please note that the following transactions must be broadcast manually.");
            console.log("L1 Safe Address: %s", l1OFTAdapter.owner());
            console.log("L1 Chain ID: %d", block.chainid);
            console.log("L1 OFT Adapter: %s", address(l1OFTAdapter));
            console.log("");

            if (newRateLimitConfigs.length > 0) {
                console.log("The following rate limits need to be set: ");
                console.log("");
                for (uint256 i = 0; i < newRateLimitConfigs.length; i++) {
                    console.log(
                        "EID %s; Limit %d; Window %d",
                        newRateLimitConfigs[i].dstEid,
                        newRateLimitConfigs[i].limit,
                        newRateLimitConfigs[i].window
                    );
                }
                console.log("");
                console.log("Method: setRateLimits");
                bytes memory data =
                    abi.encodeWithSelector(L1YnOFTAdapterUpgradeable.setRateLimits.selector, newRateLimitConfigs);
                console.log("Encoded Tx Data: ");
                console.logBytes(data);

                addToBatch(address(l1OFTAdapter), data);
                console.log("");
            }

            if (newPeers.length > 0) {
                console.log("The following peers need to be set: ");
                console.log("");
                for (uint256 i = 0; i < newPeers.length; i++) {
                    console.log("EID %d; Peer %s", newPeers[i].eid, newPeers[i].peer);
                    console.log("Method: setPeer");
                    bytes memory data =
                        abi.encodeWithSelector(IOAppCore.setPeer.selector, newPeers[i].eid, newPeers[i].peer);
                    console.log("Encoded Tx Data: ");
                    console.logBytes(data);
                    addToBatch(address(l1OFTAdapter), data);
                    console.log("");
                }
            }

            if (newSendLibs.length > 0) {
                console.log("The following send libraries need to be set: ");
                console.log("");
                for (uint256 i = 0; i < newSendLibs.length; i++) {
                    console.log(
                        "OFTAdapter %s; EID %d; Send Library %s",
                        address(l1OFTAdapter),
                        newSendLibs[i].eid,
                        newSendLibs[i].lib
                    );
                }
                console.log("");
                console.log("Method: setSendLibrary");
                bytes memory data = abi.encodeWithSelector(
                    ILayerZeroEndpointV2.setSendLibrary.selector, newSendLibs[i].eid, newSendLibs[i].lib
                );
                console.log("Encoded Tx Data: ");
                console.logBytes(data);

                addToBatch(address(lzEndpoint), data);
                console.log("");
            }

            if (newReceiveLibs.length > 0) {
                console.log("The following receive libraries need to be set: ");
                console.log("");
                for (uint256 i = 0; i < newReceiveLibs.length; i++) {
                    console.log(
                        "OFTAdapter %s; EID %d; Receive Library %s; Expiry 0",
                        address(l1OFTAdapter),
                        newReceiveLibs[i].eid,
                        newReceiveLibs[i].lib
                    );
                }
                console.log("");
                console.log("Method: setReceiveLibrary");
                bytes memory data = abi.encodeWithSelector(
                    ILayerZeroEndpointV2.setReceiveLibrary.selector,
                    address(l1OFTAdapter),
                    newReceiveLibs[i].eid,
                    newReceiveLibs[i].lib,
                    0
                );
                console.log("Encoded Tx Data: ");
                console.logBytes(data);

                addToBatch(address(lzEndpoint), data);
                console.log("");
            }

            displayBatch();
        }
    }
}
