/* solhint-disable no-console, gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    BaseScript,
    ChainDeployment,
    DVNConfigs,
    ExecutorConfigParams,
    ILZEndpointDelegates,
    PeerConfig,
    PeerRecord,
    ReceiveLibConfig,
    SendLibConfig
} from "../BaseScript.s.sol";
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

import {OAppOptionsType3Upgradeable} from
    "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";

import {IOAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {console} from "forge-std/console.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";

import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";

import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";

// forge script DisableSendOFT --rpc-url ${rpc} \
// --sig "run(string calldata,string calldata)" ${input_path} ${deployment_path} \
// --account ${deployerAccountName} --sender ${deployer}
contract DisableSendOFT is BaseScript, BatchScript {
    RateLimiter.RateLimitConfig[] public newRateLimitConfigs;
    PeerRecord[] public newPeers;
    SendLibConfig[] public newSendLibs;
    ReceiveLibConfig[] public newReceiveLibs;
    bytes[] public newEnforcedOptions;
    DVNConfigs[] public newDVNs;
    ExecutorConfigParams[] public newExecutors;
    bool public newDelegate;

    function run(
        string calldata _jsonPath,
        string calldata _deploymentPath
    )
        public
        isBatch(getData(block.chainid).OFT_OWNER)
    {
        string memory _fullDeploymentPath = string(abi.encodePacked(vm.projectRoot(), _deploymentPath));
        _loadInput(_jsonPath, _fullDeploymentPath);

        console.log("OFT_OWNER: %s", getData(block.chainid).OFT_OWNER);

        // ensure erc20 and oft adapter are deployed
        if (!isContract(currentDeployment.erc20Address)) {
            revert(string.concat("ERC20 not deployed for ", vm.toString(block.chainid)));
        }
        if (!isContract(currentDeployment.oftAdapter)) {
            revert(string.concat("OFT Adapter not deployed for ", vm.toString(block.chainid)));
        }

        uint256[] memory chainIds = new uint256[](baseInput.l2ChainIds.length + 1);

        for (uint256 i = 0; i < baseInput.l2ChainIds.length; i++) {
            chainIds[i] = baseInput.l2ChainIds[i];
        }
        chainIds[baseInput.l2ChainIds.length] = baseInput.l1ChainId;

        ILayerZeroEndpointV2 lzEndpoint = ILayerZeroEndpointV2(getData(block.chainid).LZ_ENDPOINT);

        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 chainId = chainIds[i];
            uint32 eid = getEID(chainId);

            {
                // disable send to all but the L1
                if (
                    lzEndpoint.getSendLibrary(currentDeployment.oftAdapter, eid)
                        != getData(block.chainid).LZ_BLOCK_SEND_LIB && chainId != block.chainid
                        && chainId != baseInput.l1ChainId
                ) {
                    newSendLibs.push(SendLibConfig(eid, getData(block.chainid).LZ_BLOCK_SEND_LIB));
                }
            }
        }

        addToBatch_configureSendLibs(lzEndpoint);
    }

    function addToBatch_configureSendLibs(ILayerZeroEndpointV2 _lzEndpoint) internal {
        if (newSendLibs.length > 0) {
            console.log("The following send libraries need to be set: ");
            console.log("");
            for (uint256 i = 0; i < newSendLibs.length; i++) {
                console.log("");
                console.log("Contract: %s (index: %s)", address(_lzEndpoint), i);
                console.log("Method: setSendLibrary");
                console.log("Sets the send library for the OFT Adapter on the specified EID");
                console.log("Args: ");
                uint256 chainIdForEid = getChainIdFromEID(newSendLibs[i].eid);
                console.log(
                    string(
                        abi.encodePacked(
                            "Endpoint: ",
                            vm.toString(address(_lzEndpoint)),
                            "; OFTAdapter address: ",
                            vm.toString(currentDeployment.oftAdapter),
                            "; EID: ",
                            vm.toString(newSendLibs[i].eid),
                            "; ChainID: ",
                            vm.toString(chainIdForEid),
                            "; Send Library Address: ",
                            vm.toString(newSendLibs[i].lib)
                        )
                    )
                );
                console.log("");

                if (currentDeployment.chainId == 6900) {
                    console.log("For chain nibiru we set peer to 0");
                    bytes memory data =
                        abi.encodeWithSelector(IOAppCore.setPeer.selector, newSendLibs[i].eid, address(0));
                    console.log("Encoded Tx Data: ");
                    console.logBytes(data);

                    if (Ownable(currentDeployment.oftAdapter).owner() != getData(block.chainid).OFT_OWNER) {
                        _addToBatch_disableSendOFT(address(currentDeployment.oftAdapter), 0, data);
                    } else {
                        addToBatch(address(currentDeployment.oftAdapter), 0, data);
                    }
                } else {
                    bytes memory data = abi.encodeWithSelector(
                        IMessageLibManager.setSendLibrary.selector,
                        currentDeployment.oftAdapter,
                        newSendLibs[i].eid,
                        newSendLibs[i].lib
                    );
                    console.log("Encoded Tx Data: ");
                    console.logBytes(data);

                    if (Ownable(currentDeployment.oftAdapter).owner() != getData(block.chainid).OFT_OWNER) {
                        _addToBatch_disableSendOFT(address(_lzEndpoint), 0, data);
                    } else {
                        addToBatch(address(_lzEndpoint), 0, data);
                    }
                }
                console.log("");
            }
        } else {
            console.log("No send library configuration needed.");
        }
    }

    function _addToBatch_disableSendOFT(
        address to_,
        uint256 value_,
        bytes memory data_
    )
        public
        isBatch(msg.sender)
        returns (bytes memory)
    {
        console.log("msg.sender", msg.sender);
        return addToBatch(to_, value_, data_);
    }
}
