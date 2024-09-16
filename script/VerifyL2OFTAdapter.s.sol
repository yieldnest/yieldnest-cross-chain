/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript, PeerConfig} from "./BaseScript.s.sol";

import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {ImmutableMultiChainDeployer} from "@/factory/ImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";

// forge script script/VerifyL2OFTAdapter.s.sol:DeployL2Adapter \
// --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
// --account ${deployerAccountName} --sender ${deployer}

contract VerifyL2OFTAdapter is BaseScript {
    ImmutableMultiChainDeployer public multiChainDeployer;
    L2YnOFTAdapterUpgradeable public l2OFTAdapter;
    L2YnERC20Upgradeable public l2ERC20;

    RateLimiter.RateLimitConfig[] public newRateLimitConfigs;
    PeerConfig[] public newPeers;

    function run(string calldata _jsonPath) public {
        _loadInput(_jsonPath);

        require(currentDeployment.isL1 != true, "Must be L2 deployment");

        if (!isContract(currentDeployment.multiChainDeployer)) {
            revert("ImmutableMultiChainDeployer not deployed");
        }

        require(
            address(currentDeployment.multiChainDeployer) == predictions.l2MultiChainDeployer,
            "Predicted ImmutableMultiChainDeployer address mismatch"
        );

        multiChainDeployer = ImmutableMultiChainDeployer(currentDeployment.multiChainDeployer);

        if (!isContract(currentDeployment.erc20Address)) {
            revert("L2 ERC20 not deployed");
        }

        require(address(currentDeployment.erc20Address) == predictions.l2Erc20, "Predicted ERC20 address mismatch");

        l2ERC20 = L2YnERC20Upgradeable(predictions.l2Erc20);

        if (!isContract(currentDeployment.oftAdapter)) {
            revert("L2 OFT Adapter not deployed");
        }
        require(
            address(currentDeployment.oftAdapter) == predictions.l2OftAdapter,
            "Predicted OFT Adapter address mismatch"
        );
        l2OFTAdapter = L2YnOFTAdapterUpgradeable(predictions.l2OftAdapter);

        if (l2OFTAdapter.owner() != getAddresses().OFT_DELEGATE) {
            revert("OFT Adapter ownership not transferred");
        }

        if (l2ERC20.hasRole(l2ERC20.DEFAULT_ADMIN_ROLE(), msg.sender)) {
            revert("Token Admin Role not renounced");
        }

        if (!l2ERC20.hasRole(l2ERC20.MINTER_ROLE(), address(l2OFTAdapter))) {
            revert("OFT Adapter not Minter");
        }
        if (!l2ERC20.hasRole(l2ERC20.DEFAULT_ADMIN_ROLE(), getAddresses().TOKEN_ADMIN)) {
            revert("Token Admin Role not set");
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
            (,, uint256 limit, uint256 window) = l2OFTAdapter.rateLimits(eid);
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
            address adapter = chainId == baseInput.l1ChainId ? predictions.l1OftAdapter : predictions.l2OftAdapter;
            bytes32 adapterBytes32 = addressToBytes32(adapter);
            if (l2OFTAdapter.peers(eid) != adapterBytes32) {
                needsUpdate = true;
                console.log("Peer %s at %d not set", adapter, eid);
                newPeers.push(PeerConfig(eid, adapter));
            }
        }

        bytes[] memory setPeersMultiSendTxs;

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
                setPeersMultiSendTxs = new bytes[](newPeers.length);
                console.log("New peers");
                for (uint256 i = 0; i < newPeers.length; i++) {
                    console.log("EID %d: Peer %s", newPeers[i].eid, newPeers[i].peer);
                    bytes memory newTx = abi.encodePacked(
                        uint8(0),
                        bytes20(address(l2OFTAdapter)),
                        bytes32(0),
                        abi.encodeWithSelector(
                            L2YnOFTAdapterUpgradeable.setPeer.selector, newPeers[i].eid, newPeers[i].peer
                        )
                    );
                    setPeersMultiSendTxs[i] = newTx;
                    console.log("New Multisend tx: ");
                    console.logBytes(newTx);
                }
            }
        }
    }
}
