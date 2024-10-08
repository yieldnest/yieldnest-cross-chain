/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";

import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {ImmutableMultiChainDeployer} from "@/factory/ImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

import {Ownable} from "@openzeppelin/contracts-5/access/Ownable.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts-5/proxy/transparent/TransparentUpgradeableProxy.sol";

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

        bytes32 salt = createImmutableMultiChainDeployerSalt(msg.sender);

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

        bytes32 proxySalt = createL2YnERC20UpgradeableProxySalt(msg.sender);
        bytes32 implementationSalt = createL2YnERC20UpgradeableSalt(msg.sender);

        address CURRENT_SIGNER = msg.sender;

        address predictedERC20 = multiChainDeployer.getDeployed(proxySalt);
        require(predictedERC20 == predictions.l2ERC20, "Prediction mismatch");

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

            address newOwner = getData(block.chainid).PROXY_ADMIN;
            console.log("Changing owner for L2ERC20 to: %s", newOwner);
            Ownable(getTransparentUpgradeableProxyAdminAddress(address(l2ERC20))).transferOwnership(newOwner);

            console.log("Deployed L2ERC20 at: %s", address(l2ERC20));
        } else {
            l2ERC20 = L2YnERC20Upgradeable(currentDeployment.erc20Address);
            console.log("Already deployed L2ERC20 at: %s", address(l2ERC20));
        }

        require(predictedERC20 == address(l2ERC20), "Prediction mismatch");

        proxySalt = createL2YnOFTAdapterUpgradeableProxySalt(msg.sender);
        implementationSalt = createL2YnOFTAdapterUpgradeableSalt(msg.sender);

        address predictedOFTAdapter = multiChainDeployer.getDeployed(proxySalt);
        require(predictedOFTAdapter == predictions.l2OFTAdapter, "Prediction mismatch");

        if (!isContract(currentDeployment.oftAdapter)) {
            vm.broadcast();
            l2OFTAdapter = L2YnOFTAdapterUpgradeable(
                multiChainDeployer.deployL2YnOFTAdapter(
                    implementationSalt,
                    proxySalt,
                    address(l2ERC20),
                    getData(block.chainid).LZ_ENDPOINT,
                    CURRENT_SIGNER,
                    CURRENT_SIGNER,
                    type(L2YnOFTAdapterUpgradeable).creationCode
                )
            );

            vm.broadcast();

            address newOwner = getData(block.chainid).PROXY_ADMIN;
            console.log("Changing owner for L2OFTAdapter to: %s", newOwner);
            Ownable(getTransparentUpgradeableProxyAdminAddress(address(l2OFTAdapter))).transferOwnership(newOwner);

            console.log("Deployed L2OFTAdapter at: %s", address(l2OFTAdapter));
        } else {
            l2OFTAdapter = L2YnOFTAdapterUpgradeable(currentDeployment.oftAdapter);
            console.log("Already deployed L2OFTAdapter at: %s", address(l2OFTAdapter));
        }

        require(predictedOFTAdapter == address(l2OFTAdapter), "Prediction mismatch");

        if (l2OFTAdapter.owner() == CURRENT_SIGNER) {
            vm.broadcast();
            l2OFTAdapter.setRateLimits(_getRateLimitConfigs());
            console.log("Set rate limits");

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
                    chainId == baseInput.l1ChainId ? predictions.l1OFTAdapter : predictions.l2OFTAdapter;
                bytes32 adapterBytes32 = addressToBytes32(adapter);
                if (l2OFTAdapter.peers(eid) == adapterBytes32) {
                    console.log("Already set peer for chainid %d", chainId);
                    continue;
                }

                vm.broadcast();
                l2OFTAdapter.setPeer(eid, adapterBytes32);
                console.log("Set peer for chainid %d", chainId);
            }

            vm.broadcast();
            l2OFTAdapter.transferOwnership(getData(block.chainid).OFT_OWNER);
        }

        if (l2ERC20.hasRole(l2ERC20.DEFAULT_ADMIN_ROLE(), CURRENT_SIGNER)) {
            vm.startBroadcast();
            l2ERC20.grantRole(l2ERC20.MINTER_ROLE(), address(l2OFTAdapter));
            l2ERC20.grantRole(l2ERC20.DEFAULT_ADMIN_ROLE(), getData(block.chainid).TOKEN_ADMIN);
            l2ERC20.renounceRole(l2ERC20.DEFAULT_ADMIN_ROLE(), CURRENT_SIGNER);
            vm.stopBroadcast();
        }

        currentDeployment.erc20Address = address(l2ERC20);
        currentDeployment.oftAdapter = address(l2OFTAdapter);

        _saveDeployment();
    }
}
