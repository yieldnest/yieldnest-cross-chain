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

        if (currentDeployment.oftAdapter != address(0)) {
            console.log("L1 OFT Adapter already deployed at: %s", currentDeployment.oftAdapter);
            l1OFTAdapter = L1YnOFTAdapterUpgradeable(currentDeployment.oftAdapter);
            bool needsChange = false;

            for (uint256 i = 0; i < rateLimitConfigs.length; i++) {
                (,, uint256 limit, uint256 window) = l1OFTAdapter.rateLimits(rateLimitConfigs[i].dstEid);
                RateLimiter.RateLimitConfig memory config = rateLimitConfigs[i];
                if (config.limit != limit || config.window != window) {
                    needsChange = true;
                    break;
                }
            }
            if (!needsChange) {
                console.log("Rate limits are already set");
                return;
            }
            vm.broadcast();
            // sender needs LIMITER role
            l1OFTAdapter.setRateLimits(rateLimitConfigs);

            console.log("Rate limits updated");
            return;
        }

        bytes32 proxySalt = createSalt(msg.sender, "L1YnOFTAdapterUpgradeableProxy");
        bytes32 implementationSalt = createSalt(msg.sender, "L1YnOFTAdapterUpgradeable");

        vm.startBroadcast();

        address l1OFTAdapterImpl = address(
            new L1YnOFTAdapterUpgradeable{salt: implementationSalt}(
                baseInput.l1ERC20Address, getAddresses().LZ_ENDPOINT
            )
        );

        bytes memory initializeData = abi.encodeWithSelector(
            L1YnOFTAdapterUpgradeable.initialize.selector, getAddresses().OFT_DELEGATE, rateLimitConfigs
        );

        l1OFTAdapter = L1YnOFTAdapterUpgradeable(
            address(
                new TransparentUpgradeableProxy{salt: proxySalt}(
                    l1OFTAdapterImpl, getAddresses().PROXY_ADMIN, initializeData
                )
            )
        );

        console.log("L1 OFT Adapter deployed at: %s", address(l1OFTAdapter));

        vm.stopBroadcast();

        currentDeployment.oftAdapter = address(l1OFTAdapter);

        _saveDeployment();
    }
}
