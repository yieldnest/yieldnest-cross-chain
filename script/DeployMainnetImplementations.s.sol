// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseScript} from "./BaseScript.s.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

//forge script script/DeployMainnetImplementations.s.sol:DeployMainnetImplementations --rpc-url ${rpc} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify
contract DeployMainnetImplementations is BaseScript {
    address public mainnetOFTAdapterImpl;
    L1YnOFTAdapterUpgradeable public mainnetOFTAdapter;

    function run(string memory __path) public {
        loadOFTAdapter(__path);

        vm.broadcast();

        mainnetOFTAdapterImpl =
            address(new L1YnOFTAdapterUpgradeable(_ynOFTAdapterInputs.erc20Address, addresses[_chainId].lzEndpoint));
        mainnetOFTAdapter =
            L1YnOFTAdapterUpgradeable(address(new TransparentUpgradeableProxy(mainnetOFTAdapterImpl, msg.sender, "")));

        mainnetOFTAdapter.initialize(msg.sender, _rateLimitConfigs);
    }
}
