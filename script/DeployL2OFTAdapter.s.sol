/* solhint-disable no-console, gas-custom-errors */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";

import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {ImmutableMultiChainDeployer} from "@/factory/ImmutableMultiChainDeployer.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {console} from "forge-std/console.sol";

// forge script script/DeployL2OFTAdapter.s.sol:DeployL2Adapter \
// --rpc-url ${rpc} --sig "run(string calldata)" ${path} \
// --account ${deployerAccountName} --sender ${deployer} \
// --broadcast --etherscan-api-key ${api} --verify

contract DeployL2OFTAdapter is BaseScript {
    ImmutableMultiChainDeployer public multiChainDeployer;
    L2YnOFTAdapterUpgradeable public l2OFTAdapter;
    L2YnERC20Upgradeable public l2ERC20;

    function run(string calldata _jsonPath) public {
        _loadInput(_jsonPath);

        require(currentDeployment.isL1 != true, "Must be L2 deployment");

        bytes32 proxySalt = createL2YnERC20UpgradeableProxySalt();
        bytes32 implementationSalt = createL2YnERC20UpgradeableSalt();
        bytes32 timelockSalt = createL2YnOFTAdapterTimelockSalt();

        address deployer = msg.sender;

        address predictedERC20 = multiChainDeployer.getDeployed(proxySalt);
        require(predictedERC20 == predictions.l2ERC20, "Prediction mismatch");

        address timelock = _predictTimelockController(deployer, timelockSalt);

        if (!isContract(timelock)) {
            vm.startBroadcast();
            timelock = _deployTimelockController(timelockSalt, block.chainid);
            vm.stopBroadcast();
            console.log("Timelock deployed at: ", timelock);
        } else {
            console.log("Already deployed Timelock at: ", timelock);
        }

        if (!isContract(currentDeployment.erc20Address)) {
            vm.startBroadcast();

            l2ERC20 = L2YnERC20Upgradeable(
                deployL2YnERC20(
                    implementationSalt,
                    proxySalt,
                    baseInput.erc20Name,
                    baseInput.erc20Symbol,
                    baseInput.erc20Decimals,
                    deployer,
                    timelock
                )
            );
            vm.stopBroadcast();

            console.log("Deployed L2ERC20 at: %s", address(l2ERC20));
        } else {
            l2ERC20 = L2YnERC20Upgradeable(currentDeployment.erc20Address);
            console.log("Already deployed L2ERC20 at: %s", address(l2ERC20));
        }

        require(predictedERC20 == address(l2ERC20), "Prediction mismatch");

        currentDeployment.erc20ProxyAdmin = getTransparentUpgradeableProxyAdminAddress(address(l2ERC20));
        currentDeployment.erc20Implementation =
            getTransparentUpgradeableProxyImplementationAddress(address(l2ERC20));
        currentDeployment.erc20Address = address(l2ERC20);

        proxySalt = createL2YnOFTAdapterUpgradeableProxySalt();
        implementationSalt = createL2YnOFTAdapterUpgradeableSalt();

        address predictedOFTAdapter = CREATE3_FACTORY.getDeployed(msg.sender, proxySalt);
        require(predictedOFTAdapter == predictions.l2OFTAdapter, "Prediction mismatch");

        if (!isContract(currentDeployment.oftAdapter)) {
            vm.startBroadcast();

            l2OFTAdapter = L2YnOFTAdapterUpgradeable(
                deployL2YnOFTAdapter(
                    implementationSalt,
                    proxySalt,
                    address(l2ERC20),
                    getData(block.chainid).LZ_ENDPOINT,
                    deployer,
                    timelock
                )
            );
            vm.stopBroadcast();

            console.log("Deployed L2OFTAdapter at: %s", address(l2OFTAdapter));
        } else {
            l2OFTAdapter = L2YnOFTAdapterUpgradeable(currentDeployment.oftAdapter);
            console.log("Already deployed L2OFTAdapter at: %s", address(l2OFTAdapter));
        }

        require(predictedOFTAdapter == address(l2OFTAdapter), "Prediction mismatch");

        currentDeployment.oftAdapterProxyAdmin = getTransparentUpgradeableProxyAdminAddress(address(l2OFTAdapter));
        currentDeployment.oftAdapterImplementation =
            getTransparentUpgradeableProxyImplementationAddress(address(l2OFTAdapter));
        currentDeployment.oftAdapterTimelock = ProxyAdmin(currentDeployment.oftAdapterProxyAdmin).owner();
        currentDeployment.oftAdapter = address(l2OFTAdapter);

        if (l2OFTAdapter.owner() == deployer) {
            uint256[] memory dstChainIds = baseInput.l2ChainIds;
            for (uint256 i = 0; i < dstChainIds.length; i++) {
                if (dstChainIds[i] == block.chainid) {
                    dstChainIds[i] = baseInput.l1ChainId;
                }
            }

            configureRateLimits();
            configurePeers(dstChainIds);
            configureSendLibs(dstChainIds);
            configureReceiveLibs(dstChainIds);
            configureEnforcedOptions(dstChainIds);
            configureDVNs(dstChainIds);
            configureExecutor(dstChainIds);
        }

        if (l2ERC20.hasRole(l2ERC20.DEFAULT_ADMIN_ROLE(), deployer)) {
            vm.startBroadcast();
            l2ERC20.grantRole(l2ERC20.MINTER_ROLE(), address(l2OFTAdapter));
            l2ERC20.grantRole(l2ERC20.DEFAULT_ADMIN_ROLE(), getData(block.chainid).TOKEN_ADMIN);
            l2ERC20.renounceRole(l2ERC20.DEFAULT_ADMIN_ROLE(), deployer);
            vm.stopBroadcast();
        }

        _saveDeployment();
    }
}
