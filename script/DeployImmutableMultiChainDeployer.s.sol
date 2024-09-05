// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
//forge script script/DeployImmutableMultiChainDeployer.s.sol:DeployImmutableMultiChainDeployer --rpc-url ${rpc} --sig "run(string memory)" ${path} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify

contract DeployImmutableMultiChainDeployer is Script {
    address public multiChainDeployerAddress;

    function setUp() public {}

    function run(string memory _salt) public {
        vm.broadcast();
        multiChainDeployerAddress = address(new ImmutableMultiChainDeployer{salt: _salt}());

        console.log("ImmutableMultiChainDeployer deployed at: ", multiChainDeployerAddress);
    }
}
