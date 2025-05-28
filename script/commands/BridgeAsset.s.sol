/* solhint-disable gas-custom-errors, check-send-result, one-contract-per-file */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IOFT, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {BaseData} from "../BaseData.s.sol";
import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {console} from "forge-std/console.sol";

/**
 * @notice This script bridges ynETHx tokens between chains using LayerZero OFT protocol
 *
 * @dev How it works:
 * 1. User provides destination chain ID via prompt
 * 2. If on base chain (L1):
 *    - Wraps ETH to WETH by sending ETH to WETH contract
 * 3. Bridges tokens via OFT adapter's sendFrom()
 *
 * Usage:
 * ```
 * forge script script/commands/BridgeAsset.s.sol:BridgeAssetYnETHx --rpc-url <RPC_URL> --broadcast
 * ```
 */
contract BridgeAssetYnETHx is BaseData {
    using OptionsBuilder for bytes;

    // Amount to bridge
    uint256 public constant BRIDGE_AMOUNT = 0.0001 ether;

    function run() external {
        uint256 destinationChainId =
            vm.parseUint(vm.prompt("Enter destination chain ID (e.g. 2522 for Fraxtal testnet):"));
        require(isSupportedChainId(destinationChainId), "Unsupported destination chain ID");
        uint32 destinationEid = getEID(destinationChainId);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address sender = vm.addr(deployerPrivateKey);
        address refundAddress = sender;

        console.log("Chain ID: %s", block.chainid);
        console.log("Sender: %s", sender);
        console.log("Destination Chain ID: %s", destinationChainId);
        console.log("Destination EID: %s", destinationEid);

        // Source chain ID
        // If we're on Fraxtal testnet (2522), Morph testnet (2810), or Holesky (17000),
        // use Holesky (17000) as the source chain since it's the L1 testnet.
        // Otherwise default to Ethereum mainnet (1)
        uint256 sourceChainId = block.chainid;
        uint256 baseChainId = sourceChainId == 2522 || sourceChainId == 2810 || sourceChainId == 17000 ? 17000 : 1;

        // Load deployment config
        string memory json =
            vm.readFile(string.concat("deployments/ynETHx-", vm.toString(baseChainId), "-v0.0.1.json"));

        address oftAdapter = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapter")), (address)
        );

        vm.startBroadcast(deployerPrivateKey);

        // Get the ynETHx contract address
        address ynETHx = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".erc20Address")), (address)
        );

        uint256 extraYnETHx;
        if (sourceChainId == baseChainId) {
            // Get the WETH contract address from ynETHx
            address weth = IERC4626(ynETHx).asset();

            // Get initial ynETHx balance
            uint256 initialYnETHxBalance = IERC20(ynETHx).balanceOf(sender);

            // Deposit ETH to get WETH
            (bool success,) = weth.call{value: BRIDGE_AMOUNT}("");
            require(success, "ETH to WETH deposit failed");

            // Calculate amount of WETH needed to mint BRIDGE_AMOUNT of ynETHx
            uint256 wethAmount = BRIDGE_AMOUNT;

            // Approve WETH spending
            IERC20(weth).approve(ynETHx, wethAmount);

            // Deposit WETH to mint ynETHx using ERC4626 interface
            IERC4626(ynETHx).deposit(wethAmount, sender);

            // Get final ynETHx balance and calculate extra amount received
            uint256 finalYnETHxBalance = IERC20(ynETHx).balanceOf(sender);
            extraYnETHx = finalYnETHxBalance - initialYnETHxBalance;

            console.log("Initial ynETHx balance: %s", initialYnETHxBalance);
            console.log("Final ynETHx balance: %s", finalYnETHxBalance);
            console.log("Extra ynETHx received: %s", extraYnETHx);
        } else {
            extraYnETHx = BRIDGE_AMOUNT;
        }

        if (extraYnETHx > IERC20(ynETHx).balanceOf(sender)) {
            extraYnETHx = IERC20(ynETHx).balanceOf(sender);
        }

        // Prepare bridge params
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(170000, 0);
        SendParam memory sendParam =
            SendParam(destinationEid, addressToBytes32(sender), extraYnETHx, extraYnETHx / 2, options, "", "");

        // Get messaging fee
        MessagingFee memory fee = IOFT(oftAdapter).quoteSend(sendParam, false);

        // Approve ynETHx spending on OFT adapter
        IERC20(ynETHx).approve(oftAdapter, extraYnETHx);

        // Bridge tokens
        IOFT(oftAdapter).send{value: fee.nativeFee}(sendParam, fee, payable(refundAddress));

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

/**
 * @notice This script bridges ynBTCk tokens between chains using LayerZero OFT protocol
 *
 * @dev How it works:
 * 1. User provides destination chain ID via prompt
 * 2. If on base chain (L1):
 *    - Wraps ETH to WETH by sending ETH to WETH contract
 * 3. Bridges tokens via OFT adapter's sendFrom()
 *
 * Usage:
 * ```
 * forge script script/commands/BridgeAsset.s.sol:BridgeAssetYnBTCk --rpc-url <RPC_URL> --broadcast
 * ```
 */
contract BridgeAssetYnBTCk is BaseData {
    using OptionsBuilder for bytes;

    // Amount to bridge
    uint256 public constant BRIDGE_AMOUNT = 0.00001 ether;

    function run() external {
        uint256 sourceChainId = block.chainid;
        uint256 baseChainId = 56; //bsc

        // Load deployment config
        string memory json =
            vm.readFile(string.concat("deployments/ynBTCk-", vm.toString(baseChainId), "-v0.0.2.json"));

        address oftAdapter = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapter")), (address)
        );

        uint256 destinationChainId =
            vm.parseUint(vm.prompt("Enter destination chain ID (e.g. 1 for eth mainnet):"));
        require(isSupportedChainId(destinationChainId), "Unsupported destination chain ID");
        uint32 destinationEid = getEID(destinationChainId);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address sender = vm.addr(deployerPrivateKey);

        // Get the ynBTCk contract address
        address ynBTCk = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".erc20Address")), (address)
        );

        address refundAddress = sender;

        console.log("Chain ID: %s", block.chainid);
        console.log("Sender: %s", sender);
        console.log("YNBTCK Balance: %s", IERC20(ynBTCk).balanceOf(sender));
        console.log("Destination Chain ID: %s", destinationChainId);
        console.log("Destination EID: %s", destinationEid);

        vm.startBroadcast(deployerPrivateKey);

        uint256 extraYnBTCk = BRIDGE_AMOUNT;

        if (extraYnBTCk > IERC20(ynBTCk).balanceOf(sender)) {
            extraYnBTCk = IERC20(ynBTCk).balanceOf(sender);
        }

        // Prepare bridge params
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(170000, 0);
        SendParam memory sendParam =
            SendParam(destinationEid, addressToBytes32(sender), extraYnBTCk, extraYnBTCk / 2, options, "", "");

        // Get messaging fee
        MessagingFee memory fee = IOFT(oftAdapter).quoteSend(sendParam, false);
        console.log("Fee: %s", fee.nativeFee);
        // Approve ynBTCk spending on OFT adapter
        IERC20(ynBTCk).approve(oftAdapter, extraYnBTCk);

        // Bridge tokens
        IOFT(oftAdapter).send{value: fee.nativeFee}(sendParam, fee, payable(refundAddress));

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

/**
 * @notice This script bridges ynCoBTCk tokens between chains using LayerZero OFT protocol
 *
 * @dev How it works:
 * 1. User provides destination chain ID via prompt
 * 2. If on base chain (L1):
 *    - Wraps ETH to WETH by sending ETH to WETH contract
 * 3. Bridges tokens via OFT adapter's sendFrom()
 *
 * Usage:
 * ```
 * forge script script/commands/BridgeAsset.s.sol:BridgeAssetYnCoBTCk --rpc-url <RPC_URL> --broadcast
 * ```
 */
contract BridgeAssetYnCoBTCk is BaseData {
    using OptionsBuilder for bytes;

    // Amount to bridge, min is 100
    uint256 public constant BRIDGE_AMOUNT = 100;

    function run() external {
        uint256 sourceChainId = block.chainid;
        uint256 baseChainId = 56; //bsc

        // Load deployment config
        string memory json =
            vm.readFile(string.concat("deployments/ynCoBTCk-", vm.toString(baseChainId), "-v0.0.1.json"));

        address oftAdapter = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapter")), (address)
        );

        uint256 destinationChainId =
            vm.parseUint(vm.prompt("Enter destination chain ID (e.g. 1 for eth mainnet):"));
        require(isSupportedChainId(destinationChainId), "Unsupported destination chain ID");
        uint32 destinationEid = getEID(destinationChainId);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address sender = vm.addr(deployerPrivateKey);

        // Get the ynCoBTCk contract address
        address ynCoBTCk = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".erc20Address")), (address)
        );

        address refundAddress = sender;

        console.log("Chain ID: %s", block.chainid);
        console.log("Sender: %s", sender);
        console.log("YNCOBTCK Balance: %s", IERC20(ynCoBTCk).balanceOf(sender));
        console.log("Destination Chain ID: %s", destinationChainId);
        console.log("Destination EID: %s", destinationEid);

        vm.startBroadcast(deployerPrivateKey);

        uint256 extraYnCoBTCk;
        if (sourceChainId == baseChainId) {
            // Get initial ynCoBTCk balance
            uint256 initialYnCoBTCkBalance = IERC20(ynCoBTCk).balanceOf(sender);

            address coBTC = 0x918b3aa73e2D42D96CF64CBdB16838985992dAbc;
            console.log("COBTC Balance: %s", IERC20(coBTC).balanceOf(sender));

            if (IERC4626(ynCoBTCk).asset() != coBTC) {
                console.log("Asset mismatch");
                vm.stopBroadcast();
                return;
            }

            // Calculate amount of coBTC to deposit into ynCoBTCk
            uint256 coBTCAmount = BRIDGE_AMOUNT;

            // Approve coBTC spending
            IERC20(coBTC).approve(ynCoBTCk, coBTCAmount);

            // Deposit coBTC to mint ynCoBTCk using ERC4626 interface
            IERC4626(ynCoBTCk).deposit(coBTCAmount, sender);

            // Get final ynCoBTCk balance and calculate extra amount received
            uint256 finalYnCoBTCkBalance = IERC20(ynCoBTCk).balanceOf(sender);
            extraYnCoBTCk = finalYnCoBTCkBalance - initialYnCoBTCkBalance;

            console.log("Initial ynCoBTCk balance: %s", initialYnCoBTCkBalance);
            console.log("Final ynCoBTCk balance: %s", finalYnCoBTCkBalance);
            console.log("Extra ynCoBTCk received: %s", extraYnCoBTCk);
        } else {
            extraYnCoBTCk = BRIDGE_AMOUNT;
        }

        if (extraYnCoBTCk > IERC20(ynCoBTCk).balanceOf(sender)) {
            extraYnCoBTCk = IERC20(ynCoBTCk).balanceOf(sender);
        }

        IOFT oft = IOFT(oftAdapter);

        // Prepare bridge params
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(170000, 0);
        SendParam memory sendParam =
            SendParam(destinationEid, addressToBytes32(sender), extraYnCoBTCk, extraYnCoBTCk / 2, options, "", "");

        // Get quote, this ensures the amount can be sent
        (,, OFTReceipt memory receipt) = oft.quoteOFT(sendParam);

        console.log("Receipt.amountSentLD: %s", receipt.amountSentLD);
        console.log("Receipt.amountReceivedLD: %s", receipt.amountReceivedLD);

        if (receipt.amountSentLD < extraYnCoBTCk) {
            console.log("Amount sent is less than expected, exiting");
            vm.stopBroadcast();
            return;
        }

        // Get messaging fee
        MessagingFee memory fee = oft.quoteSend(sendParam, false);
        console.log("Fee: %s", fee.nativeFee);
        // Approve ynCoBTCk spending on OFT adapter
        IERC20(ynCoBTCk).approve(oftAdapter, extraYnCoBTCk);

        // Bridge tokens
        IOFT(oftAdapter).send{value: fee.nativeFee}(sendParam, fee, payable(refundAddress));

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

/**
 * @notice This script bridges ynBNBx tokens between chains using LayerZero OFT protocol
 *
 * @dev How it works:
 * 1. User provides destination chain ID via prompt
 * 2. If on base chain (L1):
 *    - Wraps ETH to WETH by sending ETH to WETH contract
 * 3. Bridges tokens via OFT adapter's sendFrom()
 *
 * Usage:
 * ```
 * forge script script/commands/BridgeAsset.s.sol:BridgeAssetYnBNBx --rpc-url <RPC_URL> --broadcast
 * ```
 */
contract BridgeAssetYnBNBx is BaseData {
    using OptionsBuilder for bytes;

    // Amount to bridge
    uint256 public constant BRIDGE_AMOUNT = 0.00001 ether;

    function run() external {
        uint256 sourceChainId = block.chainid;
        uint256 baseChainId = 56; //bsc

        // Load deployment config
        string memory json =
            vm.readFile(string.concat("deployments/ynBNBx-", vm.toString(baseChainId), "-v0.0.1.json"));

        address oftAdapter = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapter")), (address)
        );

        uint256 destinationChainId =
            vm.parseUint(vm.prompt("Enter destination chain ID (e.g. 1 for eth mainnet):"));
        require(isSupportedChainId(destinationChainId), "Unsupported destination chain ID");
        uint32 destinationEid = getEID(destinationChainId);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address sender = vm.addr(deployerPrivateKey);

        // Get the ynBNBx contract address
        address ynBNBx = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".erc20Address")), (address)
        );

        address refundAddress = sender;

        console.log("Chain ID: %s", block.chainid);
        console.log("Sender: %s", sender);
        console.log("ynBNBx Balance: %s", IERC20(ynBNBx).balanceOf(sender));
        console.log("Destination Chain ID: %s", destinationChainId);
        console.log("Destination EID: %s", destinationEid);

        vm.startBroadcast(deployerPrivateKey);

        uint256 extraYnBNBx = BRIDGE_AMOUNT;

        if (extraYnBNBx > IERC20(ynBNBx).balanceOf(sender)) {
            extraYnBNBx = IERC20(ynBNBx).balanceOf(sender);
        }

        // Prepare bridge params
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(170000, 0);
        SendParam memory sendParam =
            SendParam(destinationEid, addressToBytes32(sender), extraYnBNBx, extraYnBNBx / 2, options, "", "");

        // Get messaging fee
        MessagingFee memory fee = IOFT(oftAdapter).quoteSend(sendParam, false);
        console.log("Fee: %s", fee.nativeFee);
        // Approve ynBNBx spending on OFT adapter
        IERC20(ynBNBx).approve(oftAdapter, extraYnBNBx);

        // Bridge tokens
        IOFT(oftAdapter).send{value: fee.nativeFee}(sendParam, fee, payable(refundAddress));

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

/**
 * @notice This script bridges YND tokens between chains using LayerZero OFT protocol
 *
 * @dev How it works:
 * 1. User provides destination chain ID via prompt
 * 2. Bridges tokens via OFT adapter's sendFrom()
 *
 * Usage:
 * ```
 * forge script script/commands/BridgeAsset.s.sol:BridgeAssetYND --rpc-url <RPC_URL> --broadcast
 * ```
 */
contract BridgeAssetYND is BaseData {
    using OptionsBuilder for bytes;

    // Amount to bridge
    uint256 public constant BRIDGE_AMOUNT = 10 ether;

    function run() external {
        uint256 sourceChainId = block.chainid;
        uint256 baseChainId = 1;

        // Load deployment config
        string memory json =
            vm.readFile(string.concat("deployments/YND-", vm.toString(baseChainId), "-v0.0.1.json"));

        address oftAdapter = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapter")), (address)
        );

        uint256 destinationChainId = vm.parseUint(vm.prompt("Enter destination chain ID (e.g. 1 for eth mainnet)"));
        require(isSupportedChainId(destinationChainId), "Unsupported destination chain ID");
        uint32 destinationEid = getEID(destinationChainId);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        //address sender = vm.addr(deployerPrivateKey);
        address sender = address(0xAB42B764D08762424f7dDde02cb7fbB7D552F64e);

        // Get the YND contract address
        address YND = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".erc20Address")), (address)
        );

        address refundAddress = sender;

        console.log("Chain ID: %s", block.chainid);
        console.log("Sender: %s", sender);
        console.log("YND Balance: %s", IERC20(YND).balanceOf(sender));
        console.log("Destination Chain ID: %s", destinationChainId);
        console.log("Destination EID: %s", destinationEid);

        //vm.startBroadcast(deployerPrivateKey);

        uint256 extraYND = BRIDGE_AMOUNT;

        if (extraYND > IERC20(YND).balanceOf(sender)) {
            extraYND = IERC20(YND).balanceOf(sender);
        }

        console.log(extraYND / 2);

        // Prepare bridge params
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(170000, 0);
        SendParam memory sendParam =
            SendParam(destinationEid, addressToBytes32(sender), extraYND, extraYND / 2, options, "", "");

        // Get messaging fee
        MessagingFee memory fee = IOFT(oftAdapter).quoteSend(sendParam, false);
        console.log("Fee: %s", fee.nativeFee);
        // Approve YND spending on OFT adapter
        //IERC20(YND).approve(oftAdapter, extraYND);

        // Print out the encoded call
        bytes memory bridgeCall = abi.encodeWithSelector(
            IOFT.send.selector,
            destinationEid,
            addressToBytes32(sender),
            extraYND,
            extraYND / 2,
            options,
            "",
            "",
            fee.nativeFee,
            fee.lzTokenFee,
            refundAddress
        );
        console.log("OFT Adapter: %s", oftAdapter);
        console.logBytes(bridgeCall);

        //vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
