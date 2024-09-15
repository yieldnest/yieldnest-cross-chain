/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";

import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {IImmutableMultiChainDeployer} from "@interfaces/IImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";

// forge script script/DeployL2OFTAdapter.s.sol:DeployL2Adapter \
// --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
// --account ${deployerAccountName} --sender ${deployer} \
// --broadcast --etherscan-api-key ${api} --verify

contract DeployL2OFTAdapter is BaseScript {
    L2YnOFTAdapterUpgradeable l2OFTAdapter;
    L2YnERC20Upgradeable l2ERC20;

    function run(string calldata _jsonPath) public {
        _loadInput(_jsonPath);

        require(currentDeployment.isL1 != true, "Must be L2 deployment");

        require(currentDeployment.multiChainDeployer != address(0), "MultiChainDeployer not deployed");

        IImmutableMultiChainDeployer currentDeployer =
            IImmutableMultiChainDeployer(currentDeployment.multiChainDeployer);

        RateLimiter.RateLimitConfig[] memory rateLimitConfigs = _getRateLimitConfigs();

        // if (currentDeployment.oftAdapter != address(0)) {
        //     console.log("L2 OFT Adapter already deployed at: %s", currentDeployment.oftAdapter);
        //     l2OFTAdapter = L2YnOFTAdapterUpgradeable(currentDeployment.oftAdapter);
        //     bool needsChange = false;

        //     for (uint256 i = 0; i < rateLimitConfigs.length; i++) {
        //         (,, uint256 limit, uint256 window) = l2OFTAdapter.rateLimits(rateLimitConfigs[i].dstEid);
        //         RateLimiter.RateLimitConfig memory config = rateLimitConfigs[i];
        //         if (config.limit != limit || config.window != window) {
        //             needsChange = true;
        //             break;
        //         }
        //     }
        //     if (!needsChange) {
        //         console.log("Rate limits are already set");
        //         return;
        //     }
        //     vm.broadcast();
        //     // sender needs LIMITER role
        //     l2OFTAdapter.setRateLimits(rateLimitConfigs);

        //     console.log("Rate limits updated");
        //     return;
        // }

        bytes32 proxySalt = createSalt(msg.sender, "L2YnERC20UpgradeableProxy");
        bytes32 implementationSalt = createSalt(msg.sender, "L2YnERC20Upgradeable");

        address CURRENT_SIGNER = msg.sender;

        vm.startBroadcast();
        l2ERC20 = L2YnERC20Upgradeable(
            currentDeployer.deployL2YnERC20(
                implementationSalt,
                proxySalt,
                baseInput.erc20Name,
                baseInput.erc20Symbol,
                CURRENT_SIGNER,
                getAddresses().PROXY_ADMIN,
                type(L2YnERC20Upgradeable).creationCode
            )
        );

        console.log("L2 ERC20 deployed at: ", address(l2ERC20));

        proxySalt = createSalt(msg.sender, "L2YnOFTAdapterUpgradeableProxy");
        implementationSalt = createSalt(msg.sender, "L2YnOFTAdapterUpgradeable");

        l2OFTAdapter = L2YnOFTAdapterUpgradeable(
            currentDeployer.deployL2YnOFTAdapter(
                implementationSalt,
                proxySalt,
                address(l2ERC20),
                getAddresses().LZ_ENDPOINT,
                CURRENT_SIGNER,
                rateLimitConfigs,
                getAddresses().PROXY_ADMIN,
                type(L2YnOFTAdapterUpgradeable).creationCode
            )
        );

        l2ERC20.grantRole(l2ERC20.MINTER_ROLE(), address(l2OFTAdapter));

        // TODO: transfer ownership after setPeers
        l2OFTAdapter.transferOwnership(getAddresses().OFT_DELEGATE);
        l2ERC20.grantRole(l2ERC20.DEFAULT_ADMIN_ROLE(), getAddresses().TOKEN_ADMIN);

        vm.stopBroadcast();

        console.log("L2 OFT Adapter deployed at: ", address(l2OFTAdapter));

        currentDeployment.erc20Address = address(l2ERC20);
        currentDeployment.oftAdapter = address(l2OFTAdapter);

        _saveDeployment();
    }
}
