// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {EndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/EndpointV2.sol";

struct YnOFTAdapterInput {
    address erc20Address;
    address lzEndpoint;
    address adapterImplementation;
    RateLimiterConfig[] rateLimitConfigs;
}

struct RateLimitConfig {
    uint32 dstEid;
    uint256 limit;
    uint256 window;
}
//forge script script/DeployMainnetImplementations.s.sol:DeployMainnetImplementations --rpc-url ${rpc} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify

contract BaseScript is Script {
    // TODO: parse token address from json or as input from user
    // TODO: setup forks based on if testnet or mainnet deployment as per json
    // TODO: setup saving of deployment data in deployments json file
    bytes public data;
    YnOFTAdapterInput public _ynOFTAdapterInputs;
    RateLimiter.RateLimitConfig[] public _rateLimitConfigs;

    function _loadJson(string memory _path) internal {
        string memory path = string(abi.encodePacked(vm.projectRoot(), "/", _path));
        string memory json = vm.readFile(path);
        data = vm.parseJson(json);
    }

    function _loadYnOFTAdapterInputs() internal {
        YnOFTAdapterInput memory _inputs = abi.decode(data, (YnOFTAdapterInput));
    }

    function _getRateLimiterConfigs() internal {
        RateLimiter.RateLimitConfig memory _tempConfig;
        uint32 tempDstEid = EndpointV2(_ynOFTAdapterInputs.lzEndpoint).eid();
        for (uint256 i; i < _ynOFTAdapterInputs.rateLimitConfigs.length; i++) {
            _tempConfig.dstEid = tempDstEid;
            _tempConfig.limit = _ynOFTAdapterInputs.rateLimitConfigs[i].limit;
            _tempConfig.window = _ynOFTAdapterInputs.rateLimitConfigs[i].window;
            _rateLimitConfigs.push(_tempConfig);
        }
    }
}
