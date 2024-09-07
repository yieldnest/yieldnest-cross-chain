// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseData} from "./BaseData.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {EndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/EndpointV2.sol";
import "forge-std/console.sol";

struct L2YnOFTAdapterInput {
    address adapterImplementation;
    uint256 chainId;
    address erc20Address;
    bytes32 implementationSalt;
    address proxyController;
    bytes32 proxySalt;
    RateLimitConfig[] rateLimitConfigs;
}

struct L1YnOFTAdapterInput {
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
    string public json;
    address public immutableDeployer;
    address public adapterImplementation;
    L2YnOFTAdapterInput public _ynOFTAdapterInputs;
    L1YnOFTAdapterInput public _ynOFTImplementationInputs;
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
        _verifyChain();
        _loadDeployerForChain(block.chainid);
        _getRateLimiterConfigs();
    }

    function _loadOFTImplementationData(string memory _inputPath) internal {
        _loadJson(_inputPath);
        _loadYnOFTImplementationInputs();
        _verifyChain();
        _getRateLimiterConfigs();
    }

    function _loadYnOFTImplementationInputs() internal {
        L1YnOFTAdapterInput memory implementationInputs = abi.decode(data, (L1YnOFTAdapterInput));
        this.loadImplementationInputs(implementationInputs);
        _chainId = _ynOFTImplementationInputs.chainId;
    }

    function _loadDeployerForChain(uint256 chainId) internal {
        string memory path = string(
            abi.encodePacked(
                vm.projectRoot(), "/deployments/ImmutableMultiChainDeployer-", vm.toString(chainId), ".json"
            )
        );
        string memory _json = vm.readFile(path);
        immutableDeployer = vm.parseJsonAddress(_json, ".ImmutableMultiChainDeployerAddress");
        require(immutableDeployer != address(0), "invalid deployer");
    }

    function _loadAdapterImplementationForChain(uint32 chainId) internal {
        string memory path = string(
            abi.encodePacked(vm.projectRoot(), "/deployments/MainnetImplementations-", vm.toString(chainId), ".json")
        );
        string memory _json = vm.readFile(path);
        adapterImplementation = vm.parseJsonAddress(_json, ".OFTAdapterImplementation");
        require(adapterImplementation != address(0), "invalid adapter Implementation");
    }

    function _loadJson(string memory _path) internal {
        string memory path = string(abi.encodePacked(vm.projectRoot(), "/", _path));
        json = vm.readFile(path);
        data = vm.parseJson(json);
    }

    function _loadYnOFTAdapterInputs() internal {
        L2YnOFTAdapterInput memory ynOFTAdapterInputs = abi.decode(data, (L2YnOFTAdapterInput));
        this.loadAdapterInputs(ynOFTAdapterInputs);
        _chainId = _ynOFTAdapterInputs.chainId;
    }

    function loadAdapterInputs(L2YnOFTAdapterInput calldata _ynInput) external {
        _ynOFTAdapterInputs = _ynInput;
    }

    function loadImplementationInputs(L1YnOFTAdapterInput calldata _ynImpInput) external {
        _ynOFTImplementationInputs = _ynImpInput;
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
        return string.concat(root, "/deployments/", _deploymentType, "-", vm.toString(block.chainid), ".json");
    }

    function _writeOutput(string memory deploymentType, string memory _json) internal {
        string memory path = _getOutputPath(deploymentType);
        vm.writeFile(path, _json);
    }

    function createSalt(address deployerAddress, string memory label) public pure returns (bytes32 _salt) {
        _salt = bytes32(abi.encodePacked(bytes20(deployerAddress), bytes12(bytes32(keccak256(abi.encode(label))))));
    }
}
