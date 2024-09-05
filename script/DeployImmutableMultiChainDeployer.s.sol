// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
//forge script script/DeployImmutableMultiChainDeployer.s.sol:DeployImmutableMultiChainDeployer --rpc-url ${rpc}  --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify

contract DeployImmutableMultiChainDeployer is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        address immutableMultiChainDeployer = address(new ImmutableMultiChainDeployer{salt: "SALT"}());

        console.log("ImmutableMultiChainDeployer deployed at: ", immutableMultiChainDeployer);
    }
}
