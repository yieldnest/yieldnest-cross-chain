/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
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

        RateLimiter.RateLimitConfig[] memory rateLimitConfigs = _getRateLimitConfigs();

        bytes32 proxySalt = createSalt(msg.sender, "L1YnOFTAdapterUpgradeableProxy");
        bytes32 implementationSalt = createSalt(msg.sender, "L1YnOFTAdapterUpgradeable");

        address CURRENT_SIGNER = msg.sender;

        if (!isContract(predictions.l1OftAdapter)) {
            vm.broadcast();
            address l1OFTAdapterImpl = address(
                new L1YnOFTAdapterUpgradeable{salt: implementationSalt}(
                    baseInput.l1ERC20Address, getAddresses().LZ_ENDPOINT
                )
            );

            bytes memory initializeData = abi.encodeWithSelector(
                L1YnOFTAdapterUpgradeable.initialize.selector, CURRENT_SIGNER, rateLimitConfigs
            );

            vm.broadcast();
            l1OFTAdapter = L1YnOFTAdapterUpgradeable(
                address(
                    new TransparentUpgradeableProxy{salt: proxySalt}(
                        l1OFTAdapterImpl, getAddresses().PROXY_ADMIN, initializeData
                    )
                )
            );
            console.log("L1 OFT Adapter deployed at: %s", address(l1OFTAdapter));
        } else {
            l1OFTAdapter = L1YnOFTAdapterUpgradeable(predictions.l1OftAdapter);
            console.log("L1 OFT Adapter already deployed at: %s", address(l1OFTAdapter));
        }

        require(address(l1OFTAdapter) == predictions.l1OftAdapter, "Deployment failed");

        if (l1OFTAdapter.owner() == CURRENT_SIGNER) {
            console.log("Setting peers");
            for (uint256 i = 0; i < deployment.chains.length; i++) {
                if (deployment.chains[i].chainId == block.chainid) {
                    continue;
                }
                uint32 eid = deployment.chains[i].lzEID;
                address adapter = predictions.l2OftAdapter;
                bytes32 adapterBytes32 = addressToBytes32(adapter);
                if (l1OFTAdapter.peers(eid) == adapterBytes32) {
                    console.log("Adapter already set for chain %d", deployment.chains[i].chainId);
                    continue;
                }

                vm.broadcast();
                l1OFTAdapter.setPeer(eid, adapterBytes32);
            }

            vm.broadcast();
            l1OFTAdapter.transferOwnership(getAddresses().OFT_DELEGATE);
        }

        currentDeployment.oftAdapter = address(l1OFTAdapter);

        _saveDeployment();
    }
}
