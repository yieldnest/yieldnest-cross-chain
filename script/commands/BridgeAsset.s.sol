/* solhint-disable gas-custom-errors, check-send-result */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IOFT, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {BaseData} from "../BaseData.s.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
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
 * forge script script/commands/BridgeAsset.s.sol:BridgeAsset --rpc-url <RPC_URL> --broadcast
 * ```
 */
contract BridgeAsset is BaseData {
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
