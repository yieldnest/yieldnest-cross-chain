/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript, PeerConfig} from "./BaseScript.s.sol";

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";

// forge script script/VerifyL1OFTAdapter.s.sol:DeployL1OFTAdapter \
// --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
// --account ${deployerAccountName} --sender ${deployer}

contract VerifyL1OFTAdapter is BaseScript {
    L1YnOFTAdapterUpgradeable public l1OFTAdapter;

    RateLimiter.RateLimitConfig[] public newRateLimitConfigs;
    PeerConfig[] public newPeers;

    function run(string calldata _jsonPath) public {
        _loadInput(_jsonPath);

        require(currentDeployment.isL1 == true, "Must be L1 deployment");

        if (!isContract(currentDeployment.oftAdapter)) {
            revert("L1 OFT Adapter not deployed");
        }

        require(address(currentDeployment.oftAdapter) == predictions.l1OftAdapter, "Predicted address mismatch");

        l1OFTAdapter = L1YnOFTAdapterUpgradeable(currentDeployment.oftAdapter);

        if (l1OFTAdapter.owner() != getAddresses().OFT_DELEGATE) {
            revert("L1 OFT Adapter ownership not transferred");
        }

        uint256[] memory chainIds = new uint256[](baseInput.l2ChainIds.length + 1);
        for (uint256 i = 0; i < baseInput.l2ChainIds.length; i++) {
            chainIds[i] = baseInput.l2ChainIds[i];
        }
        chainIds[baseInput.l2ChainIds.length] = baseInput.l1ChainId;

        bool needsUpdate = false;

        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 chainId = chainIds[i];
            uint32 eid = getEID(chainId);
            (,, uint256 limit, uint256 window) = l1OFTAdapter.rateLimits(eid);
            if (limit != baseInput.rateLimitConfig.limit || window != baseInput.rateLimitConfig.window) {
                needsUpdate = true;
                console.log("Rate limit for chain %d: %d/%d", chainId, limit, window);
                newRateLimitConfigs.push(
                    RateLimiter.RateLimitConfig(
                        eid, baseInput.rateLimitConfig.limit, baseInput.rateLimitConfig.window
                    )
                );
            }
            if (chainId == block.chainid) {
                continue;
            }
            address adapter = predictions.l2OftAdapter;
            bytes32 adapterBytes32 = addressToBytes32(adapter);
            if (l1OFTAdapter.peers(eid) != adapterBytes32) {
                needsUpdate = true;
                console.log("Peer %s at %d not set", adapter, eid);
                newPeers.push(PeerConfig(eid, adapter));
            }
        }

        if (needsUpdate) {
            // TODO: Print All this information in a much more readable manner
            // Also generate a new Multisend Gnosis Safe Tx Data that combines all the following calls for this
            // chain into a single call
            console.log("Needs update");
            if (newRateLimitConfigs.length > 0) {
                console.log("New rate limit configs");
                for (uint256 i = 0; i < newRateLimitConfigs.length; i++) {
                    console.log(
                        "EID %d: Limit of %d per window of %d",
                        newRateLimitConfigs[i].dstEid,
                        newRateLimitConfigs[i].limit,
                        newRateLimitConfigs[i].window
                    );
                }
            }
            if (newPeers.length > 0) {
                console.log("New peers");
                for (uint256 i = 0; i < newPeers.length; i++) {
                    console.log("EID %d: Peer %s", newPeers[i].eid, newPeers[i].peer);
                }
            }
        }
    }
}
