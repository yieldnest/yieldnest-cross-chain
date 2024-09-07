// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// forge script script/DeployMainnetImplementations.s.sol:DeployMainnetImplementations --rpc-url ${rpc} --sig "run(string memory)" ${path} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify
contract DeployMainnetImplementations is BaseScript {
    address public mainnetOFTAdapterImpl;
    L1YnOFTAdapterUpgradeable public mainnetOFTAdapter;

    function run(string memory __path) public {
        _loadOFTImplementationData(__path);

        _loadDeployerForChain(block.chainid);

        vm.broadcast();

        mainnetOFTAdapterImpl = address(
            new L1YnOFTAdapterUpgradeable(_ynOFTImplementationInputs.erc20Address, addresses[_chainId].lzEndpoint)
        );
        mainnetOFTAdapter =
            L1YnOFTAdapterUpgradeable(address(new TransparentUpgradeableProxy(mainnetOFTAdapterImpl, msg.sender, "")));

        mainnetOFTAdapter.initialize(msg.sender, _rateLimitConfigs);

        _serializeOutputs("MainnetImplementations");
    }

    function _serializeOutputs(string memory objectKey) internal override {
        vm.serializeAddress(objectKey, "erc20", _ynOFTImplementationInputs.erc20Address);
        vm.serializeString(objectKey, "chainid", vm.toString(block.chainid));
        vm.serializeAddress(objectKey, "OFTAdapterImplementation", address(mainnetOFTAdapterImpl));
        string memory finalJson = vm.serializeAddress(objectKey, "OFTAdapter", address(mainnetOFTAdapter));
        _writeOutput("MainnetImplementations", finalJson);
    }
}
