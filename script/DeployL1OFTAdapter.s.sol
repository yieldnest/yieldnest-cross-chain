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

        bytes32 proxySalt = createL1YnOFTAdapterUpgradeableProxySalt(msg.sender);
        bytes32 implementationSalt = createL1YnOFTAdapterUpgradeableSalt(msg.sender);
        bytes32 timelockSalt = createL1YnOFTAdapterTimelockSalt(msg.sender);

        address deployer = msg.sender;

        address timelock = _predictTimelockController(timelockSalt, block.chainid);

        if (!isContract(timelock)) {
            vm.startBroadcast();
            timelock = _deployTimelockController(timelockSalt, block.chainid);
            vm.stopBroadcast();
            console.log("Timelock deployed at: ", timelock);
        } else {
            console.log("Already deployed Timelock at: ", timelock);
        }

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

        if (l1OFTAdapter.owner() == deployer) {
            vm.broadcast();
            l1OFTAdapter.setRateLimits(_getRateLimitConfigs());
            console.log("Set rate limits");

            for (uint256 i = 0; i < baseInput.l2ChainIds.length; i++) {
                uint256 chainId = baseInput.l2ChainIds[i];
                uint32 eid = getEID(chainId);
                address adapter = predictions.l2OFTAdapter;
                bytes32 adapterBytes32 = addressToBytes32(adapter);
                if (l1OFTAdapter.peers(eid) == adapterBytes32) {
                    console.log("Already set peer for chainid %d", chainId);
                    continue;
                }

                vm.broadcast();
                l1OFTAdapter.setPeer(eid, adapterBytes32);
                console.log("Set peer for chainid %d", chainId);
            }

            vm.broadcast();
            l1OFTAdapter.transferOwnership(getData(block.chainid).OFT_OWNER);
        }

        currentDeployment.oftAdapterProxyAdmin = getTransparentUpgradeableProxyAdminAddress(address(l1OFTAdapter));
        currentDeployment.oftAdapterTimelock = ProxyAdmin(currentDeployment.oftAdapterProxyAdmin).owner();
        currentDeployment.oftAdapter = address(l1OFTAdapter);

        _saveDeployment();
    }
}
