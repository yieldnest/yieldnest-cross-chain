/* solhint-disable no-console, gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";

import {
    ProxyAdmin,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {console} from "forge-std/console.sol";

// forge script script/DeployL1OFTAdapter.s.sol:DeployL1OFTAdapter \
// --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
// --account ${deployerAccountName} --sender ${deployer} \
// --broadcast --etherscan-api-key ${api} --verify

contract DeployL1OFTAdapter is BaseScript {
    L1YnOFTAdapterUpgradeable public l1OFTAdapter;

    function run(string calldata _jsonPath) public {
        _loadInput(_jsonPath);

        require(currentDeployment.isL1 == true, "Must be L1 deployment");
        address deployer = msg.sender;

        bytes32 proxySalt = createL1YnOFTAdapterUpgradeableProxySalt();
        bytes32 implementationSalt = createL1YnOFTAdapterUpgradeableSalt();
        bytes32 timelockSalt = createL1YnOFTAdapterTimelockSalt();

        address timelock = _predictTimelockController(deployer, timelockSalt);

        if (!isContract(timelock)) {
            vm.startBroadcast();
            timelock = _deployTimelockController(timelockSalt, block.chainid);
            vm.stopBroadcast();
            console.log("Timelock deployed at: ", timelock);
        } else {
            console.log("Already deployed Timelock at: ", timelock);
        }

        currentDeployment.erc20ProxyAdmin = getTransparentUpgradeableProxyAdminAddress(baseInput.l1ERC20Address);
        currentDeployment.erc20Implementation =
            getTransparentUpgradeableProxyImplementationAddress(baseInput.l1ERC20Address);
        currentDeployment.erc20Address = baseInput.l1ERC20Address;

        if (!isContract(currentDeployment.oftAdapter)) {
            vm.broadcast();
            address l1OFTAdapterImpl = address(
                new L1YnOFTAdapterUpgradeable{salt: implementationSalt}(
                    baseInput.l1ERC20Address, getData(block.chainid).LZ_ENDPOINT
                )
            );

            bytes memory initializeData =
                abi.encodeWithSelector(L1YnOFTAdapterUpgradeable.initialize.selector, deployer);

            vm.startBroadcast();
            l1OFTAdapter = L1YnOFTAdapterUpgradeable(
                address(
                    new TransparentUpgradeableProxy{salt: proxySalt}(l1OFTAdapterImpl, timelock, initializeData)
                )
            );
            vm.stopBroadcast();

            console.log("Deployed L1OFTAdapter at: %s", address(l1OFTAdapter));
        } else {
            l1OFTAdapter = L1YnOFTAdapterUpgradeable(currentDeployment.oftAdapter);
            console.log("Already deployed L1OFTAdapter at: %s", address(l1OFTAdapter));
        }

        require(address(l1OFTAdapter) == predictions.l1OFTAdapter, "Prediction mismatch");

        currentDeployment.oftAdapterProxyAdmin = getTransparentUpgradeableProxyAdminAddress(address(l1OFTAdapter));
        currentDeployment.oftAdapterImplementation =
            getTransparentUpgradeableProxyImplementationAddress(address(l1OFTAdapter));
        currentDeployment.oftAdapterTimelock = ProxyAdmin(currentDeployment.oftAdapterProxyAdmin).owner();
        currentDeployment.oftAdapter = address(l1OFTAdapter);

        if (l1OFTAdapter.owner() == deployer) {
            uint256[] memory dstChainIds = baseInput.l2ChainIds;

            configureRateLimits();
            configurePeers(dstChainIds);
            configureSendLibs(dstChainIds);
            configureReceiveLibs(dstChainIds);
            configureEnforcedOptions(dstChainIds);
            configureDVNs(dstChainIds);
            configureExecutor(dstChainIds);
        }

        _saveDeployment();
    }
}
