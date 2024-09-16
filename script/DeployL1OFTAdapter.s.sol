/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {
    ITransparentUpgradeableProxy,
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

        bytes32 proxySalt = createSalt(msg.sender, "L1YnOFTAdapterUpgradeableProxy");
        bytes32 implementationSalt = createSalt(msg.sender, "L1YnOFTAdapterUpgradeable");

        address CURRENT_SIGNER = msg.sender;

        if (!isContract(currentDeployment.oftAdapter)) {
            vm.broadcast();
            address l1OFTAdapterImpl = address(
                new L1YnOFTAdapterUpgradeable{salt: implementationSalt}(
                    baseInput.l1ERC20Address, getAddresses().LZ_ENDPOINT
                )
            );

            bytes memory initializeData =
                abi.encodeWithSelector(L1YnOFTAdapterUpgradeable.initialize.selector, CURRENT_SIGNER);

            vm.broadcast();
            l1OFTAdapter = L1YnOFTAdapterUpgradeable(
                address(
                    new TransparentUpgradeableProxy{salt: proxySalt}(l1OFTAdapterImpl, msg.sender, initializeData)
                )
            );

            vm.broadcast();
            ITransparentUpgradeableProxy(address(l1OFTAdapter)).changeAdmin(getAddresses().PROXY_ADMIN);
            console.log("Deployer L1OFTAdapter at: %s", address(l1OFTAdapter));
        } else {
            l1OFTAdapter = L1YnOFTAdapterUpgradeable(currentDeployment.oftAdapter);
            console.log("Already deployed L1OFTAdapter at: %s", address(l1OFTAdapter));
        }

        require(address(l1OFTAdapter) == predictions.l1OftAdapter, "Prediction mismatch");

        if (l1OFTAdapter.owner() == CURRENT_SIGNER) {
            console.log("Setting rate limits");
            vm.broadcast();
            l1OFTAdapter.setRateLimits(_getRateLimitConfigs());

            console.log("Setting peers");
            for (uint256 i = 0; i < baseInput.l2ChainIds.length; i++) {
                uint256 chainId = baseInput.l2ChainIds[i];
                uint32 eid = getEID(chainId);
                address adapter = predictions.l2OftAdapter;
                bytes32 adapterBytes32 = addressToBytes32(adapter);
                if (l1OFTAdapter.peers(eid) == adapterBytes32) {
                    console.log("Peer already set for chain %d", chainId);
                    continue;
                }

                vm.broadcast();
                l1OFTAdapter.setPeer(eid, adapterBytes32);
                console.log("Set Peer %s for eid %d", adapter, eid);
            }

            vm.broadcast();
            l1OFTAdapter.transferOwnership(getAddresses().OFT_DELEGATE);
        }

        currentDeployment.oftAdapter = address(l1OFTAdapter);

        _saveDeployment();
    }
}
