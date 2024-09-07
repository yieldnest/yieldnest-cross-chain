// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";
import {IImmutableMultiChainDeployer} from "@interfaces/IImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/console.sol";
// forge script script/DeployL2Adapter.s.sol:DeployL2Adapter --rpc-url ${rpc} --sig "run(string memory)" ${path} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify

contract DeployL2Adapter is BaseScript {
    address l2YnOFTAdapter;

    function run(string memory __path) public {
        _loadOFTAdapterData(__path);
        l2YnOFTAdapter = IImmutableMultiChainDeployer(immutableDeployer).deployL2YnOFTAdapter(
            _ynOFTAdapterInputs.implementationSalt,
            _ynOFTAdapterInputs.proxySalt,
            _ynOFTAdapterInputs.erc20Address,
            addresses[_chainId].lzEndpoint,
            msg.sender,
            _rateLimitConfigs,
            _ynOFTAdapterInputs.proxyController,
            type(L2YnOFTAdapterUpgradeable).creationCode
        );

        _serializeOutputs("l2OFTAdapter");
    }

    function _serializeOutputs(string memory objectKey) internal override {
        vm.serializeString(objectKey, "chainid", vm.toString(block.chainid));
        vm.serializeAddress(objectKey, "deployer", msg.sender);
        vm.serializeUint(objectKey, "dstEid", uint256(_rateLimitConfigs[0].dstEid));
        vm.serializeJson(objectKey, json);
        string memory finalJson = vm.serializeAddress(objectKey, "l2YnOFTAdapter", address(l2YnOFTAdapter));
        _writeOutput("L2OFTAdapter", finalJson);
    }
}
