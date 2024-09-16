/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";

import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {ImmutableMultiChainDeployer} from "@/factory/ImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
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

        bytes32 salt = createSalt(msg.sender, "ImmutableMultiChainDeployer");

        address predictedAddress = predictions.l2MultiChainDeployer;
        if (!isContract(currentDeployment.multiChainDeployer)) {
            vm.broadcast();
            multiChainDeployer = new ImmutableMultiChainDeployer{salt: salt}();
            console.log("Deployed ImmutableMultiChainDeployer at: ", address(multiChainDeployer));
        } else {
            console.log("Already deployed ImmutableMultiChainDeployer at: ", currentDeployment.multiChainDeployer);
            multiChainDeployer = ImmutableMultiChainDeployer(predictedAddress);
        }

        require(address(multiChainDeployer) == predictedAddress, "Prediction mismatch");

        currentDeployment.multiChainDeployer = address(multiChainDeployer);

        bytes32 proxySalt = createSalt(msg.sender, "L2YnERC20UpgradeableProxy");
        bytes32 implementationSalt = createSalt(msg.sender, "L2YnERC20Upgradeable");

        address CURRENT_SIGNER = msg.sender;

        address predictedERC20 = multiChainDeployer.getDeployed(proxySalt);
        require(predictedERC20 == predictions.l2Erc20, "Prediction mismatch");

        if (!isContract(currentDeployment.erc20Address)) {
            vm.broadcast();
            l2ERC20 = L2YnERC20Upgradeable(
                multiChainDeployer.deployL2YnERC20(
                    implementationSalt,
                    proxySalt,
                    baseInput.erc20Name,
                    baseInput.erc20Symbol,
                    CURRENT_SIGNER,
                    CURRENT_SIGNER,
                    type(L2YnERC20Upgradeable).creationCode
                )
            );

            vm.broadcast();
            ITransparentUpgradeableProxy(address(l2ERC20)).changeAdmin(getAddresses().PROXY_ADMIN);

            console.log("Deployed L2ERC20 at: %s", address(l2ERC20));
        } else {
            l2ERC20 = L2YnERC20Upgradeable(currentDeployment.erc20Address);
            console.log("Already deployed L2ERC20 at: %s", address(l2ERC20));
        }

        require(predictedERC20 == address(l2ERC20), "Prediction mismatch");

        proxySalt = createSalt(msg.sender, "L2YnOFTAdapterUpgradeableProxy");
        implementationSalt = createSalt(msg.sender, "L2YnOFTAdapterUpgradeable");

        address predictedOFTAdapter = multiChainDeployer.getDeployed(proxySalt);
        require(predictedOFTAdapter == predictions.l2OftAdapter, "Prediction mismatch");

        if (!isContract(currentDeployment.oftAdapter)) {
            vm.broadcast();
            l2OFTAdapter = L2YnOFTAdapterUpgradeable(
                multiChainDeployer.deployL2YnOFTAdapter(
                    implementationSalt,
                    proxySalt,
                    address(l2ERC20),
                    getAddresses().LZ_ENDPOINT,
                    CURRENT_SIGNER,
                    CURRENT_SIGNER,
                    type(L2YnOFTAdapterUpgradeable).creationCode
                )
            );

            vm.broadcast();
            ITransparentUpgradeableProxy(address(l2OFTAdapter)).changeAdmin(getAddresses().PROXY_ADMIN);

            console.log("Deployed L2OFTAdapter at: %s", address(l2OFTAdapter));
        } else {
            l2OFTAdapter = L2YnOFTAdapterUpgradeable(currentDeployment.oftAdapter);
            console.log("Already deployed L2OFTAdapter at: %s", address(l2OFTAdapter));
        }

        require(predictedOFTAdapter == address(l2OFTAdapter), "Prediction mismatch");

        if (l2OFTAdapter.owner() == CURRENT_SIGNER) {
            console.log("Setting rate limits");
            vm.broadcast();
            l2OFTAdapter.setRateLimits(_getRateLimitConfigs());

            console.log("Setting peers");

            uint256[] memory chainIds = new uint256[](baseInput.l2ChainIds.length + 1);
            for (uint256 i = 0; i < baseInput.l2ChainIds.length; i++) {
                chainIds[i] = baseInput.l2ChainIds[i];
            }
            chainIds[baseInput.l2ChainIds.length] = baseInput.l1ChainId;

            for (uint256 i = 0; i < chainIds.length; i++) {
                uint256 chainId = chainIds[i];
                if (chainId == block.chainid) {
                    continue;
                }
                uint32 eid = getEID(chainId);
                address adapter =
                    chainId == baseInput.l1ChainId ? predictions.l1OftAdapter : predictions.l2OftAdapter;
                bytes32 adapterBytes32 = addressToBytes32(adapter);
                if (l2OFTAdapter.peers(eid) == adapterBytes32) {
                    console.log("Peer already set for chain %d", chainId);
                    continue;
                }

                vm.broadcast();
                l2OFTAdapter.setPeer(eid, adapterBytes32);
                console.log("Set Peer %s for eid %d", adapter, eid);
            }

            vm.broadcast();
            l2OFTAdapter.transferOwnership(getAddresses().OFT_DELEGATE);
        }

        if (l2ERC20.hasRole(l2ERC20.DEFAULT_ADMIN_ROLE(), CURRENT_SIGNER)) {
            vm.startBroadcast();
            l2ERC20.grantRole(l2ERC20.MINTER_ROLE(), address(l2OFTAdapter));
            l2ERC20.grantRole(l2ERC20.DEFAULT_ADMIN_ROLE(), getAddresses().TOKEN_ADMIN);
            l2ERC20.renounceRole(l2ERC20.DEFAULT_ADMIN_ROLE(), CURRENT_SIGNER);
            vm.stopBroadcast();
        }

        currentDeployment.erc20Address = address(l2ERC20);
        currentDeployment.oftAdapter = address(l2OFTAdapter);

        _saveDeployment();
    }
}
