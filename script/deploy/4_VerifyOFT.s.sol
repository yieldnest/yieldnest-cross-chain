/* solhint-disable no-console, gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript, ChainDeployment, PeerConfig, ReceiveLibConfig, SendLibConfig} from "../BaseScript.s.sol";
import {BatchScript} from "../BatchScript.s.sol";

import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";

import {IOAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {
    ILayerZeroEndpointV2,
    IMessageLibManager
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {console} from "forge-std/console.sol";
import {OAppOptionsType3Upgradeable} from
    "lib/LayerZero-v2/oapp/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import {OptionsBuilder} from "lib/LayerZero-v2/oapp/contracts/oapp/libs/OptionsBuilder.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// forge script VerifyOFT --rpc-url ${rpc} \
// --sig "run(string calldata,string calldata)" ${input_path} ${deployment_path} \
// --account ${deployerAccountName} --sender ${deployer}

contract VerifyOFT is BaseScript, BatchScript {
    RateLimiter.RateLimitConfig[] public newRateLimitConfigs;
    PeerConfig[] public newPeers;
    SendLibConfig[] public newSendLibs;
    ReceiveLibConfig[] public newReceiveLibs;
    bytes[] public newEnforcedOptions;
    bytes[] public newDvns;
    bytes[] public newExecutor;

    function run(
        string calldata _jsonPath,
        string calldata _deploymentPath
    )
        public
        isBatch(getData(block.chainid).OFT_OWNER)
    {
        string memory _fullDeploymentPath = string(abi.encodePacked(vm.projectRoot(), _deploymentPath));
        _loadInput(_jsonPath, _fullDeploymentPath);

        // ensure erc20 and oft adapter are deployed
        if (!isContract(currentDeployment.erc20Address)) {
            revert(string.concat("ERC20 not deployed for ", vm.toString(block.chainid)));
        }
        if (!isContract(currentDeployment.oftAdapter)) {
            revert(string.concat("OFT Adapter not deployed for ", vm.toString(block.chainid)));
        }

        {
            // verify oft adapter proxy admin
            address proxyAdmin = getTransparentUpgradeableProxyAdminAddress(currentDeployment.oftAdapter);
            if (proxyAdmin != currentDeployment.oftAdapterProxyAdmin) {
                revert(string.concat("OFT Adapter proxy admin is not correct for ", vm.toString(block.chainid)));
            }
            address proxyAdminOwner = ProxyAdmin(proxyAdmin).owner();
            if (proxyAdminOwner != currentDeployment.oftAdapterTimelock) {
                revert(
                    string.concat(
                        "Timelock is not owner of OFT Adapter proxy admin for ", vm.toString(block.chainid)
                    )
                );
            }
            TimelockController timelock = TimelockController(payable(currentDeployment.oftAdapterTimelock));
            if (!timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), getData(block.chainid).PROXY_ADMIN)) {
                revert(
                    string.concat(
                        "Proxy admin does not have DEFAULT_ADMIN_ROLE on timelock for ", vm.toString(block.chainid)
                    )
                );
            }
        }

        if (currentDeployment.isL1 == false) {
            // verify erc20 roles
            L2YnERC20Upgradeable l2ERC20 = L2YnERC20Upgradeable(currentDeployment.erc20Address);

            if (l2ERC20.hasRole(l2ERC20.DEFAULT_ADMIN_ROLE(), msg.sender)) {
                revert(
                    string.concat(
                        "Deployer has DEFAULT_ADMIN_ROLE not renounced on ERC20 for ", vm.toString(block.chainid)
                    )
                );
            }

            if (!l2ERC20.hasRole(l2ERC20.MINTER_ROLE(), currentDeployment.oftAdapter)) {
                revert(
                    string.concat(
                        "OFT Adapter does not have MINTER_ROLE on ERC20 for ", vm.toString(block.chainid)
                    )
                );
            }

            if (!l2ERC20.hasRole(l2ERC20.DEFAULT_ADMIN_ROLE(), getData(block.chainid).TOKEN_ADMIN)) {
                revert(
                    string.concat(
                        "Token admin does not have DEFAULT_ADMIN_ROLE on ERC20 for ", vm.toString(block.chainid)
                    )
                );
            }

            // verify erc20 proxy admin
            address proxyAdmin = getTransparentUpgradeableProxyAdminAddress(currentDeployment.erc20Address);
            if (proxyAdmin != currentDeployment.erc20ProxyAdmin) {
                revert(string.concat("ERC20 proxy admin is not correct for ", vm.toString(block.chainid)));
            }
            address proxyAdminOwner = ProxyAdmin(proxyAdmin).owner();
            if (proxyAdminOwner != currentDeployment.oftAdapterTimelock) {
                revert(
                    string.concat("Timelock is not owner of ERC20 proxy admin for ", vm.toString(block.chainid))
                );
            }
            TimelockController timelock = TimelockController(payable(currentDeployment.oftAdapterTimelock));
            if (!timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), getData(block.chainid).PROXY_ADMIN)) {
                revert(
                    string.concat(
                        "Proxy admin does not have DEFAULT_ADMIN_ROLE on timelock for ", vm.toString(block.chainid)
                    )
                );
            }
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

            ChainDeployment memory chainDeployment = findChainDeployment(chainId);

            (,, uint256 limit, uint256 window) = RateLimiter(payable(currentDeployment.oftAdapter)).rateLimits(eid);
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
            address adapter = chainDeployment.oftAdapter;
            bytes32 adapterBytes32 = addressToBytes32(adapter);
            if (IOAppCore(currentDeployment.oftAdapter).peers(eid) != adapterBytes32) {
                needsUpdate = true;
                newPeers.push(PeerConfig(eid, adapter));
            }
            if (lzEndpoint.getSendLibrary(currentDeployment.oftAdapter, eid) != getData(block.chainid).LZ_SEND_LIB)
            {
                needsUpdate = true;
                newSendLibs.push(SendLibConfig(eid, getData(block.chainid).LZ_SEND_LIB));
            }
            (address lib, bool isDefault) = lzEndpoint.getReceiveLibrary(adapter, eid);
            if (lib != getData(block.chainid).LZ_RECEIVE_LIB && isDefault != false) {
                needsUpdate = true;
                newReceiveLibs.push(ReceiveLibConfig(eid, getData(block.chainid).LZ_RECEIVE_LIB));
            }
            EnforcedOptionParam[] memory enforcedOptions = _getEnforcedOptions(chainId);
            if (
                keccak256(OAppOptionsType3Upgradeable(currentDeployment.oftAdapter).enforcedOptions(eid, 1))
                    != keccak256(enforcedOptions[0].options)
                    || keccak256(OAppOptionsType3Upgradeable(currentDeployment.oftAdapter).enforcedOptions(eid, 2))
                        != keccak256(enforcedOptions[1].options)
            ) {
                needsUpdate = true;
                newEnforcedOptions.push(getConfigureEnforcedOptionsTX(chainId));
            }

            // configure dvns
            bytes memory ulnConfig = abi.encode(_getUlnConfig(chainId));
            if (
                keccak256(
                    lzEndpoint.getConfig(
                        currentDeployment.oftAdapter, getData(block.chainid).LZ_RECEIVE_LIB, eid, CONFIG_TYPE_ULN
                    )
                ) != keccak256(ulnConfig)
                    || keccak256(
                        lzEndpoint.getConfig(
                            currentDeployment.oftAdapter, getData(block.chainid).LZ_SEND_LIB, eid, CONFIG_TYPE_ULN
                        )
                    ) != keccak256(ulnConfig)
            ) {
                needsUpdate = true;
                (bytes memory encodedSendTx, bytes memory encodedReceiveTx) = getConfigureDVNsTX(chainId);
                newDvns.push(encodedSendTx);
                newDvns.push(encodedReceiveTx);
            }
            //configure executor
            ExecutorConfig memory executorConfig = ExecutorConfig({
                maxMessageSize: DEFAULT_MAX_MESSAGE_SIZE,
                executor: getData(block.chainid).LZ_EXECUTOR
            });
            if (
                keccak256(
                    lzEndpoint.getConfig(
                        currentDeployment.oftAdapter, getData(block.chainid).LZ_SEND_LIB, eid, CONFIG_TYPE_EXECUTOR
                    )
                ) != keccak256(abi.encode(executorConfig))
            ) {
                needsUpdate = true;
                (bytes memory encodedSendTx) = getConfigureExecutorTX(chainIds[i]);
                newDvns.push(encodedSendTx);
            }
        }

        Ownable oftAdapterOwnable = Ownable(currentDeployment.oftAdapter);

        if (oftAdapterOwnable.owner() != getData(block.chainid).OFT_OWNER) {
            console.log("OFT Adapter ownership: %s", oftAdapterOwnable.owner());
            console.log("Expected ownership: %s", getData(block.chainid).OFT_OWNER);

            if (needsUpdate) {
                revert(
                    string.concat(
                        "OFT Adapter ownership is not correct & config needs to be updated for ",
                        vm.toString(block.chainid)
                    )
                );
            }
        }

        if (needsUpdate) {
            console.log("");
            console.log("Please note that the following transactions must be broadcast manually.");
            console.log("Safe Address: %s", getData(block.chainid).OFT_OWNER);
            console.log("Chain ID: %d", block.chainid);
            console.log("OFT Adapter: %s", currentDeployment.oftAdapter);
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

                addToBatch(currentDeployment.oftAdapter, data);
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
                    addToBatch(currentDeployment.oftAdapter, data);
                    console.log("");
                }
            }

            if (newSendLibs.length > 0) {
                console.log("The following send libraries need to be set: ");
                console.log("");
                for (uint256 i = 0; i < newSendLibs.length; i++) {
                    console.log(
                        "OFTAdapter %s; EID %d; Send Library %s",
                        currentDeployment.oftAdapter,
                        newSendLibs[i].eid,
                        newSendLibs[i].lib
                    );
                    console.log("");
                    console.log("Method: setSendLibrary");
                    bytes memory data = abi.encodeWithSelector(
                        IMessageLibManager.setSendLibrary.selector,
                        currentDeployment.oftAdapter,
                        newSendLibs[i].eid,
                        newSendLibs[i].lib
                    );
                    console.log("Encoded Tx Data: ");
                    console.logBytes(data);

                    addToBatch(address(lzEndpoint), data);
                    console.log("");
                }
            }

            if (newReceiveLibs.length > 0) {
                console.log("The following receive libraries need to be set: ");
                console.log("");
                for (uint256 i = 0; i < newReceiveLibs.length; i++) {
                    console.log(
                        "OFTAdapter %s; EID %d; Receive Library %s; Expiry 0",
                        currentDeployment.oftAdapter,
                        newReceiveLibs[i].eid,
                        newReceiveLibs[i].lib
                    );
                    console.log("");
                    console.log("Method: setReceiveLibrary");
                    bytes memory data = abi.encodeWithSelector(
                        IMessageLibManager.setReceiveLibrary.selector,
                        currentDeployment.oftAdapter,
                        newReceiveLibs[i].eid,
                        newReceiveLibs[i].lib,
                        0
                    );
                    console.log("Encoded Tx Data: ");
                    console.logBytes(data);

                    addToBatch(address(lzEndpoint), data);
                    console.log("");
                }
            }

            if (newEnforcedOptions.length > 0) {
                console.log("The following enforced options need to be set: ");
                console.log("");
                for (uint256 i = 0; i < newEnforcedOptions.length; i++) {
                    console.log("Encoded Tx Data: ");
                    console.logBytes(newEnforcedOptions[i]);
                    addToBatch(address(lzEndpoint), newEnforcedOptions[i]);
                    console.log("");
                }
            }

            if (newDvns.length > 0) {
                console.log("The following DVNs need to be set: ");
                console.log("");
                for (uint256 i = 0; i < newDvns.length; i++) {
                    console.log("Encoded Tx Data: ");
                    console.logBytes(newDvns[i]);
                    addToBatch(address(lzEndpoint), newDvns[i]);
                    console.log("");
                }
            }

            if (newExecutor.length > 0) {
                console.log("The following executor need to be set: ");
                console.log("");
                for (uint256 i = 0; i < newExecutor.length; i++) {
                    console.log("Encoded Tx Data: ");
                    console.logBytes(newExecutor[i]);
                    addToBatch(address(lzEndpoint), newExecutor[i]);
                    console.log("");
                }
            }

            displayBatch();
        }
    }
}
