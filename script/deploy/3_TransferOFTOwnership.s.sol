/* solhint-disable no-console, gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseScript} from "../BaseScript.s.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {console} from "forge-std/console.sol";

// forge script TransferOFTOwnership --rpc-url ${rpc} \
// --sig "run(string calldata,string calldata)" ${input_path} ${deployment_path} \
// --account ${deployerAccountName} --sender ${deployer} --broadcast

contract TransferOFTOwnership is BaseScript {
    error InvalidDeployment();
    error NotOwner();

    function run(string calldata _jsonPath, string calldata _deploymentPath) public {
        string memory _fullDeploymentPath = string(abi.encodePacked(vm.projectRoot(), _deploymentPath));
        _loadInput(_jsonPath, _fullDeploymentPath);

        if (currentDeployment.oftAdapter == address(0)) {
            revert InvalidDeployment();
        }

        Ownable oftAdapter = Ownable(currentDeployment.oftAdapter);

        if (oftAdapter.owner() != getData(block.chainid).OFT_OWNER) {
            if (oftAdapter.owner() != msg.sender) {
                revert NotOwner();
            }

            vm.broadcast();
            Ownable(currentDeployment.oftAdapter).transferOwnership(getData(block.chainid).OFT_OWNER);
            console.log("OFT Ownership transferred to:", oftAdapter.owner());
        } else {
            console.log("OFT Ownership already transferred");
        }
    }
}
