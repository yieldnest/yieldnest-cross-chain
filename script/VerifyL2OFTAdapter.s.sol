/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript, PeerConfig} from "./BaseScript.s.sol";
import {BatchScript} from "./BatchScript.s.sol";

import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {ImmutableMultiChainDeployer} from "@/factory/ImmutableMultiChainDeployer.sol";

import {IOAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";

// forge script script/VerifyL2OFTAdapter.s.sol:DeployL2Adapter \
// --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
// --account ${deployerAccountName} --sender ${deployer}

contract VerifyL2OFTAdapter is BaseScript, BatchScript {
    ImmutableMultiChainDeployer public multiChainDeployer;
    L2YnOFTAdapterUpgradeable public l2OFTAdapter;
    L2YnERC20Upgradeable public l2ERC20;

    RateLimiter.RateLimitConfig[] public newRateLimitConfigs;
    PeerConfig[] public newPeers;

    function run(string calldata _jsonPath) public isBatch(getAddresses().OFT_DELEGATE) {
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
            "Predicted L2 OFT Adapter address mismatch"
        );
        l2OFTAdapter = L2YnOFTAdapterUpgradeable(predictions.l2OftAdapter);

        if (l2OFTAdapter.owner() != getAddresses().OFT_DELEGATE) {
            revert("L2 OFT Adapter ownership not transferred");
        }

        vm.prank(getAddresses().PROXY_ADMIN);
        if (ITransparentUpgradeableProxy(address(l2OFTAdapter)).admin() != getAddresses().PROXY_ADMIN) {
            revert("L2 OFT Adapter proxy admin not set");
        }

        if (l2ERC20.hasRole(l2ERC20.DEFAULT_ADMIN_ROLE(), msg.sender)) {
            revert("Token Admin Role not renounced");
        }

        if (!l2ERC20.hasRole(l2ERC20.MINTER_ROLE(), address(l2OFTAdapter))) {
            revert("L2 OFT Adapter not Minter");
        }
        if (!l2ERC20.hasRole(l2ERC20.DEFAULT_ADMIN_ROLE(), getAddresses().TOKEN_ADMIN)) {
            revert("Token Admin Role not set");
        }

        vm.prank(getAddresses().PROXY_ADMIN);
        if (ITransparentUpgradeableProxy(address(l2ERC20)).admin() != getAddresses().PROXY_ADMIN) {
            revert("L2 ERC20 proxy admin not set");
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
                newPeers.push(PeerConfig(eid, adapter));
            }
        }

        if (needsUpdate) {
            console.log("");
            console.log("Please note that the following transactions must be broadcast manually.");
            console.log("L2 Safe Address: %s", l2OFTAdapter.owner());
            console.log("L2 Chain ID: %d", block.chainid);
            console.log("L2 OFT Adapter: %s", address(l2OFTAdapter));
            console.log("");

            if (newRateLimitConfigs.length > 0) {
                console.log("The following rate limits need to be set: ");
                console.log("");
                for (uint256 i = 0; i < newRateLimitConfigs.length; i++) {
                    console.log(
                        "EID %d: Limit %d, Window %d",
                        newRateLimitConfigs[i].dstEid,
                        newRateLimitConfigs[i].limit,
                        newRateLimitConfigs[i].window
                    );
                }
                console.log("");
                console.log("Method: setRateLimits");
                bytes memory data =
                    abi.encodeWithSelector(L2YnOFTAdapterUpgradeable.setRateLimits.selector, newRateLimitConfigs);
                console.log("Encoded Tx Data: ");
                console.logBytes(data);

                addToBatch(address(l2OFTAdapter), data);
            }
            console.log("");

            if (newPeers.length > 0) {
                console.log("The following peers need to be set: ");
                console.log("");
                for (uint256 i = 0; i < newPeers.length; i++) {
                    console.log("EID %d: Peer %s", newPeers[i].eid, newPeers[i].peer);
                    console.log("Method: setPeer");
                    bytes memory data =
                        abi.encodeWithSelector(IOAppCore.setPeer.selector, newPeers[i].eid, newPeers[i].peer);
                    console.log("Encoded Tx Data: ");
                    console.logBytes(data);
                    addToBatch(address(l2OFTAdapter), data);
                }
            }
            console.log("");

            displayBatch();

            console.log("");
        }
    }
}
