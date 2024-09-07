// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import "forge-std/console.sol";

//forge script script/DeployMultiChainDeployer.s.sol:DeployMultiChainDeployer --rpc-url ${rpc} --sig "run(string calldata)" ${path} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify

contract DeployMultiChainDeployer is BaseScript {
    address public multiChainDeployerAddress;

    function run(string calldata _jsonPath) public {
        _loadInput(_jsonPath);

        require(currentDeployment.isL1 != true, "Must be L2 deployment");

        bytes32 salt = createSalt(msg.sender, "ImmutableMultiChainDeployer");

        address predictedAddress =
            vm.computeCreate2Address(salt, keccak256(type(ImmutableMultiChainDeployer).creationCode));
        console.log("Predicted ImmutableMultiChainDeployer address: ", predictedAddress);

        if (currentDeployment.multiChainDeployer != address(0)) {
            require(currentDeployment.multiChainDeployer == predictedAddress, "Already deployed");
            console.log("ImmutableMultiChainDeployer already deployed at: ", currentDeployment.multiChainDeployer);
            return;
        }

        vm.broadcast();
        multiChainDeployerAddress = address(new ImmutableMultiChainDeployer{salt: salt}());

        console.log("ImmutableMultiChainDeployer deployed at: ", multiChainDeployerAddress);
        require(multiChainDeployerAddress == predictedAddress, "Deployment failed");

        currentDeployment.multiChainDeployer = multiChainDeployerAddress;

        _saveDeployment();
    }
}
