/* solhint-disable no-console, gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {console} from "forge-std/console.sol";
import {ERC20Sample} from "src/sample/ERC20Sample.sol";

contract DeployERC20Sample is Script {
    function run() public {
        vm.startBroadcast();
        ERC20Sample sampleContract = new ERC20Sample("ERC20Sample 2", "ERC20Sample-2");
        console.log("SampleContract deployed at:", address(sampleContract));
        vm.stopBroadcast();
    }
}
