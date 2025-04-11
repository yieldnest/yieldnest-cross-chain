/* solhint-disable no-console, gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
import {BaseScript} from "script/BaseScript.s.sol";
import {BatchScript} from "script/BatchScript.s.sol";

// forge script ConfigureOFT --rpc-url ${rpc} \
// --sig "run(string calldata,string calldata)" ${input_path} ${deployment_path} \
// --account ${deployerAccountName} --sender ${deployer} --broadcast

contract ConfigureOFT is BaseScript {
    function run(string calldata _jsonPath, string calldata _deploymentPath) public {
        string memory _fullDeploymentPath = string(abi.encodePacked(vm.projectRoot(), _deploymentPath));
        _loadInput(_jsonPath, _fullDeploymentPath);

        address deployer = msg.sender;

        Ownable oftAdapter = Ownable(currentDeployment.oftAdapter);

        if (oftAdapter.owner() == deployer) {
            uint256[] memory dstChainIds = baseInput.l2ChainIds;
            for (uint256 i = 0; i < dstChainIds.length; i++) {
                if (dstChainIds[i] == block.chainid) {
                    dstChainIds[i] = baseInput.l1ChainId;
                }
            }

            configureRateLimits();
            configurePeers(dstChainIds);
            configureSendLibs(dstChainIds);
            configureReceiveLibs(dstChainIds);
            configureEnforcedOptions(dstChainIds);
            configureDVNs(dstChainIds);
            configureExecutor(dstChainIds);
        }
    }
}

// forge script GetConfigTx --rpc-url ${rpc} \
// --sig "run(string calldata,string calldata)" ${input_path} ${deployment_path} \
// --account ${deployerAccountName} --sender ${deployer} --broadcast

contract GetConfigTx is BaseScript, BatchScript {
    address configurer;

    function run(string calldata _jsonPath, string calldata _deploymentPath) public {
        string memory _fullDeploymentPath = string(abi.encodePacked(vm.projectRoot(), _deploymentPath));
        _loadInput(_jsonPath, _fullDeploymentPath);

        configurer = getData(block.chainid).OFT_OWNER;

        Ownable oftAdapter = Ownable(currentDeployment.oftAdapter);
        address _toAddress;
        bytes memory _encodedTX;
        if (oftAdapter.owner() == configurer) {
            uint256[] memory dstChainIds = baseInput.l2ChainIds;
            for (uint256 i = 0; i < dstChainIds.length; i++) {
                if (dstChainIds[i] == block.chainid) {
                    dstChainIds[i] = baseInput.l1ChainId;
                }
                console.log("Encoding Config Transactions for chain: ", dstChainIds[i]);

                (_toAddress, _encodedTX) = getConfigureRateLimitsTX();
                _addToBatch(_toAddress, _encodedTX);

                (_toAddress, _encodedTX) = getConfigurePeersTX(dstChainIds[i]);
                _addToBatch(_toAddress, _encodedTX);

                (_toAddress, _encodedTX) = getConfigureSendLibTX(dstChainIds[i]);
                _addToBatch(_toAddress, _encodedTX);

                (_toAddress, _encodedTX) = getConfigureReceiveLibTX(dstChainIds[i]);
                _addToBatch(_toAddress, _encodedTX);

                (_toAddress, _encodedTX) = getConfigureEnforcedOptionsTX(dstChainIds[i]);
                _addToBatch(_toAddress, _encodedTX);

                bytes memory sendEncodedTx;
                bytes memory receiveEncodedTX;
                (_toAddress, sendEncodedTx, receiveEncodedTX) = getConfigureDVNsTX(dstChainIds[i]);
                _addToBatch(_toAddress, sendEncodedTx);
                _addToBatch(_toAddress, receiveEncodedTX);

                (_toAddress, _encodedTX) = getConfigureExecutorTX(dstChainIds[i]);
                _addToBatch(_toAddress, _encodedTX);
            }

            for (uint256 i = 0; i < encodedTxns.length; i++) {
                console.log("Encoded Config Transactions for chain: ", encodedTxns[i]);
            }
        }
    }

    function _addToBatch(address adapter, bytes memory encodedTx) internal isBatch(configurer) {
        require(configurer != address(0), "Current Safe is not set");
        if (adapter != address(0) && encodedTx.length > 0) {
            addToBatch(adapter, 0, encodedTx);
        }
    }
}
