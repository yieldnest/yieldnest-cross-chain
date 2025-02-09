/* solhint-disable no-console, gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {console} from "forge-std/console.sol";

// forge script script/TransferOFTOwnership.s.sol:TransferOFTOwnership \
// --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
// --account ${deployerAccountName} --sender ${deployer} \
// --broadcast --etherscan-api-key ${api} --verify

contract TransferOFTOwnership is BaseScript {
    error InvalidDeployment();
    error NotOwner();

    function run(string calldata _jsonPath) public {
        _loadInput(_jsonPath);

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
            console.log("OFT Ownership transferred");
        } else {
            console.log("OFT Ownership already transferred");
        }
    }
}
