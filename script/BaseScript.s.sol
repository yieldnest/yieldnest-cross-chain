// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseData} from "./BaseData.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {EndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/EndpointV2.sol";

struct YnOFTAdapterInput {
    address adapterImplementation;
    uint256 chainId;
    address erc20Address;
    RateLimitConfig[] rateLimitConfigs;
}

struct RateLimitConfig {
    uint256 limit;
    uint256 window;
}

struct YnERC20Input {
    uint256 chainId;
    address erc20Address;
    string name;
    string symbol;
}
//forge script script/DeployMainnetImplementations.s.sol:DeployMainnetImplementations --rpc-url ${rpc} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify

contract BaseScript is BaseData {
    // TODO: parse token address from json or as input from user
    // TODO: setup forks based on if testnet or mainnet deployment as per json
    // TODO: setup saving of deployment data in deployments json file
    uint256 _chainId;
    bytes public data;
    YnOFTAdapterInput public _ynOFTAdapterInputs;
    YnERC20Input public _ynERC20Inputs;
    RateLimiter.RateLimitConfig[] public _rateLimitConfigs;

    function _loadERC20Data(string memory _inputPath) internal {
        _loadJson(_inputPath);
        _loadYnERC20Inputs();
        _verifyChain();
    }

    function _loadOFTAdapterData(string memory _inputPath) internal {
        _loadJson(_inputPath);
        _loadYnOFTAdapterInputs();
        _getRateLimiterConfigs();
        _verifyChain();
    }

    function _loadJson(string memory _path) internal {
        string memory path = string(abi.encodePacked(vm.projectRoot(), "/", _path));
        string memory json = vm.readFile(path);
        data = vm.parseJson(json);
    }

    function _loadYnOFTAdapterInputs() internal {
        YnOFTAdapterInput memory ynOFTAdapterInputs = abi.decode(data, (YnOFTAdapterInput));
        _chainId = _ynOFTAdapterInputs.chainId;
        this.loadAdapterInputs(ynOFTAdapterInputs);
    }

    function loadAdapterInputs(YnOFTAdapterInput calldata _ynInput) external {
        _ynOFTAdapterInputs = _ynInput;
    }

    function _loadYnERC20Inputs() internal {
        _ynERC20Inputs = abi.decode(data, (YnERC20Input));
        _chainId = _ynERC20Inputs.chainId;
    }

    function _getRateLimiterConfigs() internal {
        RateLimiter.RateLimitConfig memory _tempConfig;
        uint32 tempDstEid = EndpointV2(addresses[_chainId].lzEndpoint).eid();
        for (uint256 i; i < _ynOFTAdapterInputs.rateLimitConfigs.length; i++) {
            _tempConfig.dstEid = tempDstEid;
            _tempConfig.limit = _ynOFTAdapterInputs.rateLimitConfigs[i].limit;
            _tempConfig.window = _ynOFTAdapterInputs.rateLimitConfigs[i].window;
            _rateLimitConfigs.push(_tempConfig);
        }
    }

    function _serializeOutputs(string memory objectKey) internal virtual {
        // left blank on purpose
    }

    function _verifyChain() internal view returns (bool) {
        require(isSupportedChainId(_chainId) && block.chainid == _chainId, "Invalid chain");
        return isSupportedChainId(_chainId) && block.chainid == _chainId;
    }

    function _getOutputPath(string memory _deploymentType) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return string.concat(root, "/script/output/", _deploymentType, "-", vm.toString(block.chainid), ".json");
    }

    function _writeOutput(string memory deploymentType, string memory json) internal {
        string memory path = _getOutputPath("ImmutableMultiChainDeployer");
        vm.writeFile(path, json);
    }
}
