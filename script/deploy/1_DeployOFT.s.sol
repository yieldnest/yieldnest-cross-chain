/* solhint-disable no-console, gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseScript} from "script/BaseScript.s.sol";

import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {console} from "forge-std/console.sol";

// forge script DeployOFT --rpc-url ${rpc}
// --sig "run(string calldata)" ${path} \
// --account ${deployerAccountName} --sender ${deployer} \
// --broadcast --etherscan-api-key ${api} --verify

contract DeployOFT is BaseScript {
    function run(string calldata _jsonPath) public {
        _loadInput(_jsonPath);

        console.log("Using CREATE3_FACTORY at: %s", address(getCreate3Factory()));

        address deployer = msg.sender;

        if (!isContract(currentDeployment.oftAdapterTimelock)) {
            console.log("Deploying Timelock");
            address admin = getData(block.chainid).PROXY_ADMIN;

            address[] memory proposers = new address[](1);
            proposers[0] = admin;

            address[] memory executors = new address[](1);
            executors[0] = admin;

            uint256 minDelay = getMinDelay(block.chainid);

            bytes memory constructorParams = abi.encode(minDelay, proposers, executors, admin);
            bytes memory contractCode = abi.encodePacked(type(TimelockController).creationCode, constructorParams);

            bytes32 timelockSalt = createTimelockSalt();
            address predictedTimelock = getCreate3Factory().getDeployed(deployer, timelockSalt);

            vm.startBroadcast();
            currentDeployment.oftAdapterTimelock = getCreate3Factory().deploy(timelockSalt, contractCode);
            vm.stopBroadcast();
            console.log("Timelock deployed at: ", currentDeployment.oftAdapterTimelock);
            require(predictedTimelock == currentDeployment.oftAdapterTimelock, "Timelock Prediction mismatch");
        } else {
            console.log("Already deployed Timelock at: ", currentDeployment.oftAdapterTimelock);
        }

        if (currentDeployment.isL1) {
            console.log("Already deployed L1ERC20 at: %s", baseInput.l1ERC20Address);

            currentDeployment.erc20Address = baseInput.l1ERC20Address;
        } else {
            if (!isContract(currentDeployment.erc20Address)) {
                console.log("Deploying L2ERC20");
                bytes32 proxySalt = createERC20ProxySalt();
                address predictedERC20 = getCreate3Factory().getDeployed(deployer, proxySalt);

                vm.startBroadcast();
                currentDeployment.erc20Address = deployL2YnERC20(
                    proxySalt,
                    baseInput.erc20Name,
                    baseInput.erc20Symbol,
                    baseInput.erc20Decimals,
                    deployer,
                    currentDeployment.oftAdapterTimelock
                );

                vm.stopBroadcast();

                console.log("L2ERC20 deployer at: %s", currentDeployment.erc20Address);
                require(predictedERC20 == currentDeployment.erc20Address, "ERC20 Prediction mismatch");
            } else {
                console.log("Already deployed L2ERC20 at: %s", currentDeployment.erc20Address);
            }
        }
        currentDeployment.erc20ProxyAdmin =
            getTransparentUpgradeableProxyAdminAddress(currentDeployment.erc20Address);
        currentDeployment.erc20Implementation =
            getTransparentUpgradeableProxyImplementationAddress(currentDeployment.erc20Address);

        if (!isContract(currentDeployment.oftAdapter)) {
            console.log("Deploying OFTAdapter");

            bytes32 proxySalt = createOFTAdapterProxySalt();

            address predictedOFTAdapter = getCreate3Factory().getDeployed(deployer, proxySalt);
            vm.startBroadcast();
            if (currentDeployment.isL1) {
                currentDeployment.oftAdapter = deployL1YnOFTAdapter(
                    proxySalt,
                    currentDeployment.erc20Address,
                    getData(block.chainid).LZ_ENDPOINT,
                    deployer,
                    currentDeployment.oftAdapterTimelock
                );
            } else {
                currentDeployment.oftAdapter = deployL2YnOFTAdapter(
                    proxySalt,
                    currentDeployment.erc20Address,
                    getData(block.chainid).LZ_ENDPOINT,
                    deployer,
                    currentDeployment.oftAdapterTimelock
                );
            }
            vm.stopBroadcast();
            console.log("OFTAdapter deployed at: %s", currentDeployment.oftAdapter);
            require(predictedOFTAdapter == currentDeployment.oftAdapter, "OFT Adapter Prediction mismatch");
        } else {
            console.log("Already deployed OFTAdapter at: %s", currentDeployment.oftAdapter);
        }

        currentDeployment.oftAdapterProxyAdmin =
            getTransparentUpgradeableProxyAdminAddress(currentDeployment.oftAdapter);
        currentDeployment.oftAdapterImplementation =
            getTransparentUpgradeableProxyImplementationAddress(currentDeployment.oftAdapter);

        if (!currentDeployment.isL1) {
            L2YnERC20Upgradeable l2ERC20 = L2YnERC20Upgradeable(currentDeployment.erc20Address);
            if (l2ERC20.hasRole(l2ERC20.DEFAULT_ADMIN_ROLE(), deployer)) {
                vm.startBroadcast();
                l2ERC20.grantRole(l2ERC20.MINTER_ROLE(), currentDeployment.oftAdapter);
                l2ERC20.grantRole(l2ERC20.DEFAULT_ADMIN_ROLE(), getData(block.chainid).TOKEN_ADMIN);
                l2ERC20.renounceRole(l2ERC20.DEFAULT_ADMIN_ROLE(), deployer);
                vm.stopBroadcast();
            }
        }

        _saveDeployment();
    }
}
