// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseScript} from "./BaseScript.s.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import "forge-std/console.sol";

//forge script script/DeployImmutableMultiChainDeployer.s.sol:DeployImmutableMultiChainDeployer --rpc-url ${rpc} --sig "run(bytes32)" ${salt} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify

contract DeployImmutableMultiChainDeployer is BaseScript {
    address public multiChainDeployerAddress;

    function run(bytes32 _salt) public {
        vm.broadcast();
        multiChainDeployerAddress = address(new ImmutableMultiChainDeployer{salt: _salt}());

        console.log("ImmutableMultiChainDeployer deployed at: ", multiChainDeployerAddress);
        _serializeOutputs("ImmutableMultiChainDeployer");
    }

    function _serializeOutputs(string memory objectKey) internal override {
        vm.serializeString(objectKey, "chainid", vm.toString(block.chainid));
        string memory finalJson =
            vm.serializeAddress(objectKey, "ImmutableMultiChainDeployerAddress", address(multiChainDeployerAddress));
        _writeOutput("ImmutableMultiChainDeployer", finalJson);
    }
}
