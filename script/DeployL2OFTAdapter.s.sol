// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";
import {IImmutableMultiChainDeployer} from "@interfaces/IImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/console.sol";

// forge script script/DeployL2OFTAdapter.s.sol:DeployL2Adapter --rpc-url ${rpc} --sig "run(string memory, string memory)" ${path2ERC20Input} ${path2OFTAdapterInput} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify

contract DeployL2OFTAdapter is BaseScript {
    address l2YnOFTAdapter;
    address l2ERC20Address;

    function run(string calldata _jsonPath) public {
        _loadInput(_jsonPath);

        require(currentDeployment.isL1 != true, "Must be L2 deployment");

        require(currentDeployment.multiChainDeployer != address(0), "MultiChainDeployer not deployed");

        IImmutableMultiChainDeployer currentDeployer =
            IImmutableMultiChainDeployer(currentDeployment.multiChainDeployer);

        RateLimiter.RateLimitConfig[] memory rateLimitConfigs = _getRateLimitConfigs();

        if (currentDeployment.oftAdapter != address(0)) {
            console.log("L2 OFT Adapter already deployed at: %s", currentDeployment.oftAdapter);
            L2YnOFTAdapterUpgradeable oftAdapter = L2YnOFTAdapterUpgradeable(currentDeployment.oftAdapter);
            bool needsChange = false;

            for (uint256 i = 0; i < rateLimitConfigs.length; i++) {
                (,, uint256 limit, uint256 window) = oftAdapter.rateLimits(rateLimitConfigs[i].dstEid);
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
            oftAdapter.setRateLimits(rateLimitConfigs);

            console.log("Rate limits updated");
            return;
        }

        bytes32 proxySalt = createSalt(msg.sender, "L2YnERC20UpgradeableProxy");
        bytes32 implementationSalt = createSalt(msg.sender, "L2YnERC20Upgradeable");

        vm.startBroadcast();
        l2ERC20Address = currentDeployer.deployL2YnERC20(
            implementationSalt,
            proxySalt,
            baseInput.erc20Name,
            baseInput.erc20Symbol,
            getAddresses().TOKEN_ADMIN,
            getAddresses().PROXY_ADMIN,
            type(L2YnERC20Upgradeable).creationCode
        );

        console.log("L2 ERC20 deployed at: ", l2ERC20Address);

        proxySalt = createSalt(msg.sender, "L2YnOFTAdapterUpgradeableProxy");
        implementationSalt = createSalt(msg.sender, "L2YnOFTAdapterUpgradeable");

        l2YnOFTAdapter = currentDeployer.deployL2YnOFTAdapter(
            implementationSalt,
            proxySalt,
            l2ERC20Address,
            getAddresses().LZ_ENDPOINT,
            getAddresses().OFT_DELEGATE,
            rateLimitConfigs,
            getAddresses().PROXY_ADMIN,
            type(L2YnOFTAdapterUpgradeable).creationCode
        );
        vm.stopBroadcast();

        console.log("L2 OFT Adapter deployed at: ", l2YnOFTAdapter);

        currentDeployment.erc20Address = l2ERC20Address;
        currentDeployment.oftAdapter = l2YnOFTAdapter;

        _saveDeployment();
    }
}
