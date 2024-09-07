// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";
import {IImmutableMultiChainDeployer} from "@interfaces/IImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/console.sol";
// forge script script/DeployL2Adapter.s.sol:DeployL2Adapter --rpc-url ${rpc} --sig "run(string memory, string memory)" ${path2ERC20Input} ${path2OFTAdapterInput} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify

contract DeployL2Adapter is BaseScript {
    address l2YnOFTAdapter;
    address l2ERC20Address;

    function run(string memory _erc20Inputpath, string memory _oftAdapterInputpath) public {
        _loadERC20Data(_erc20Inputpath);

        l2ERC20Address = IImmutableMultiChainDeployer(immutableDeployer).deployL2YnERC20(
            createSalt(address(0), string.concat(_ynERC20Inputs.name, "-", _ynERC20Inputs.symbol)),
            createSalt(address(0), string.concat(_ynERC20Inputs.symbol, "-", _ynERC20Inputs.name)),
            _ynERC20Inputs.name,
            _ynERC20Inputs.symbol,
            msg.sender,
            msg.sender,
            type(L2YnERC20Upgradeable).creationCode
        );
        _loadOFTAdapterData(_oftAdapterInputpath);
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
        vm.serializeAddress(objectKey, "YnErc20", l2ERC20Address);
        vm.serializeUint(objectKey, "dstEid", uint256(_rateLimitConfigs[0].dstEid));
        vm.serializeJson(objectKey, json);
        string memory finalJson = vm.serializeAddress(objectKey, "l2YnOFTAdapter", address(l2YnOFTAdapter));
        _writeOutput("L2OFTAdapter", finalJson);
    }
}
