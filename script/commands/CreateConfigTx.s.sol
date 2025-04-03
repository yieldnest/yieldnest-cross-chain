/* solhint-disable gas-custom-errors, check-send-result */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {L2YnOFTAdapterUpgradeable} from "../../src/L2YnOFTAdapterUpgradeable.sol";
import {BaseData} from "../BaseData.s.sol";
import {BaseScript, ChainDeployment, Deployment} from "../BaseScript.s.sol";
import {BatchScript} from "../BatchScript.s.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {ILayerZeroEndpointV2} from
    "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IMessageLibManager} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {console} from "forge-std/console.sol";

interface IERC20 {
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IOFTAdapter {
    function owner() external view returns (address);
}

contract CreateConfigTx is BaseData, BaseScript {
    using OptionsBuilder for bytes;

    address oftOwner;

    function _getChainIds(
        string calldata inputPath,
        string calldata deploymentPath
    )
        internal
        returns (uint256[] memory)
    {
        uint256 sourceChainId = block.chainid;

        // Load deployment config
        string memory json = vm.readFile(deploymentPath);

        __loadInput(inputPath, deploymentPath);

        address oftAdapter = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapter")), (address)
        );

        address deployer = abi.decode(vm.parseJson(json, string.concat(".deployerAddress")), (address));

        oftOwner = 0x4C51Ce7B2546e18449fbE16738A8D55bc195a4dd; //getData(sourceChainId).OFT_OWNER;

        _checkOftOwner(oftAdapter, oftOwner, deployer);

        require(isSupportedChainId(sourceChainId), "Unsupported destination chain ID");

        uint32 destinationEid = getEID(sourceChainId);

        console.log("Chain ID: %s", block.chainid);
        console.log("Sender: %s", msg.sender);
        console.log("OFT Owner: %s", oftOwner);
        console.log("Destination Chain ID: %s", sourceChainId);
        console.log("Destination EID: %s", destinationEid);

        uint256[] memory dstChainIds = baseInput.l2ChainIds;

        for (uint256 i = 0; i < dstChainIds.length; i++) {
            if (dstChainIds[i] == block.chainid) {
                dstChainIds[i] = baseInput.l1ChainId;
            }
        }

        return dstChainIds;
    }

    function _checkOftOwner(address _oftAdapter, address owner, address deployer) internal view {
        IOFTAdapter adapter = IOFTAdapter(_oftAdapter);
        address _oftOwner = adapter.owner();
        if (_oftOwner != owner && deployer == _oftOwner) {
            revert("OFT Owner is still the deployer");
        } else if (_oftOwner != owner && deployer != _oftOwner) {
            revert("OFT Owner is not security council or deployer");
        }
    }

    function __loadJson(string memory _path) private {
        string memory filePath = string(abi.encodePacked(vm.projectRoot(), _path));
        string memory json = vm.readFile(filePath);

        // Reset the baseInput struct
        delete baseInput;

        // Parse simple fields
        baseInput.erc20Name = vm.parseJsonString(json, ".erc20Name");
        baseInput.erc20Symbol = vm.parseJsonString(json, ".erc20Symbol");

        // Parse the L1Input struct
        baseInput.l1ChainId = vm.parseJsonUint(json, ".l1ChainId");
        baseInput.l1ERC20Address = vm.parseJsonAddress(json, ".l1ERC20Address");
        // Parse the L2ChainIds array
        baseInput.l2ChainIds = vm.parseJsonUintArray(json, ".l2ChainIds");

        // Parse RateLimitConfig struct
        baseInput.rateLimitConfig.limit = vm.parseJsonUint(json, ".rateLimitConfig.limit");
        baseInput.rateLimitConfig.window = vm.parseJsonUint(json, ".rateLimitConfig.window");
    }

    function __loadInput(string calldata _inputPath, string memory _deploymentPath) internal {
        console.log("Loading Input: ");
        _loadJson(_inputPath);
        _validateInput();
        bool isL1 = _getIsL1();
        _loadDeployment(_deploymentPath);
        if (deployment.deployerAddress != address(0)) {
            require(deployment.deployerAddress == msg.sender, "Invalid Deployer");
        }
        for (uint256 i; i < deployment.chains.length; i++) {
            if (deployment.chains[i].chainId == block.chainid) {
                currentDeployment = deployment.chains[i];
                break;
            }
        }
        currentDeployment.chainId = block.chainid;

        assert(currentDeployment.chainId != 0);
        currentDeployment.isL1 = isL1;
        if (isL1) {
            currentDeployment.erc20Address = baseInput.l1ERC20Address;
            require(
                keccak256(bytes(IERC20(baseInput.l1ERC20Address).symbol()))
                    == keccak256(bytes(baseInput.erc20Symbol)),
                "Invalid ERC20 Symbol"
            );

            require(
                keccak256(bytes(IERC20(baseInput.l1ERC20Address).name())) == keccak256(bytes(baseInput.erc20Name)),
                "Invalid ERC20 Name"
            );

            require(
                IERC20(baseInput.l1ERC20Address).decimals() == baseInput.erc20Decimals, "Invalid ERC20 Decimals"
            );
        }
        currentDeployment.lzEndpoint = getData(block.chainid).LZ_ENDPOINT;
        currentDeployment.lzEID = getEID(block.chainid);
        require(
            deployment.deployerAddress == address(0) || deployment.deployerAddress == msg.sender,
            "Invalid Deployer Address"
        );
    }
}

/**
 *  @dev when adding paths the first path is the input path for the original deployment and the second path is the
 * deployment json
 *  any added chains should be added to the input json.
 */

// source .env && forge script script/commands/CreateConfigTx.s.sol:CreateBatchConfigTx -s "run(string,string)"
// /script/inputs/holesky-ynETH.json deployments/ynETHx-17000-v0.0.1.json --rpc-url $HOLESKY_RPC_URL -vvvv
// --account $DEPLOYER_ACCOUNT_NAME --sender $DEPLOYER_ADDRESS
contract CreateBatchConfigTx is BaseScript, CreateConfigTx, BatchScript {
    function run(string calldata inputPath, string calldata deploymentPath) external {
        uint256[] memory dstChainIds = _getChainIds(inputPath, deploymentPath);
        address adapter;
        bytes memory encodedTx;
        console.log("Encoding Txns: ");

        for (uint256 i = 0; i < dstChainIds.length; i++) {
            console.log("Encoding Config Transactions for chain: ", dstChainIds[i]);

            (adapter, encodedTx) = getConfigureRateLimitsTX();
            _addToBatch(adapter, encodedTx);

            (adapter, encodedTx) = getConfigurePeersTX(dstChainIds[i]);
            _addToBatch(adapter, encodedTx);

            (adapter, encodedTx) = getConfigureSendLibTX(dstChainIds[i]);
            _addToBatch(adapter, encodedTx);

            (adapter, encodedTx) = getConfigureReceiveLibTX(dstChainIds[i]);
            _addToBatch(adapter, encodedTx);

            (adapter, encodedTx) = getConfigureEnforcedOptionsTX(dstChainIds[i]);
            _addToBatch(adapter, encodedTx);

            bytes memory sendEncodedTx;
            bytes memory receiveEncodedTX;
            (adapter, sendEncodedTx, receiveEncodedTX) = getConfigureDVNsTX(dstChainIds[i]);
            _addToBatch(adapter, sendEncodedTx);
            _addToBatch(adapter, receiveEncodedTX);

            (adapter, encodedTx) = getConfigureExecutorTX(dstChainIds[i]);
            _addToBatch(adapter, encodedTx);
        }

        console.log("Encoded Txns: ");
        for (uint256 i = 0; i < encodedTxns.length; i++) {
            console.logBytes(encodedTxns[i]);
        }
    }

    function _addToBatch(address adapter, bytes memory encodedTx) internal isBatch(oftOwner) {
        require(oftOwner != address(0), "Current Safe is not set");
        if (adapter != address(0) && encodedTx.length > 0) {
            addToBatch(adapter, 0, encodedTx);
        }
    }
}
