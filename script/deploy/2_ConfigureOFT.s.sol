/* solhint-disable no-console, gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "script/BaseScript.s.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";

// forge script ConfigureOFT --rpc-url ${rpc} \
// --sig "run(string calldata,string calldata,bool)" ${input_path} ${deployment_path} ${onlyL1Destination} \
// --account ${deployerAccountName} --sender ${deployer} --broadcast

contract ConfigureOFT is BaseScript {
    function run(string calldata _jsonPath, string calldata _deploymentPath, bool onlyL1Destination) public {
        string memory _fullDeploymentPath = string(abi.encodePacked(vm.projectRoot(), "/", _deploymentPath));
        _loadInput(_jsonPath, _fullDeploymentPath);

        address deployer = msg.sender;

        Ownable oftAdapter = Ownable(currentDeployment.oftAdapter);

        if (oftAdapter.owner() == deployer) {
            uint256[] memory dstChainIds = baseInput.l2ChainIds;

            if (onlyL1Destination) {
                console.log("Only L1 destination");
                dstChainIds = new uint256[](1);
                dstChainIds[0] = baseInput.l1ChainId;
            } else {
                console.log("All destinations");
                for (uint256 i = 0; i < dstChainIds.length; i++) {
                    if (dstChainIds[i] == block.chainid) {
                        dstChainIds[i] = baseInput.l1ChainId;
                    }
                }
            }

            configureRateLimits();
            configurePeers(dstChainIds);
            configureSendLibs(dstChainIds);
            configureReceiveLibs(dstChainIds);
            configureEnforcedOptions(dstChainIds);
            configureDVNs(dstChainIds);
            configureExecutor(dstChainIds);
            configureDelegate();
        }
    }
}
