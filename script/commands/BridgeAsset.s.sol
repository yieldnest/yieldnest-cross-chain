// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IOFT, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Script} from "forge-std/Script.sol";

import {console} from "forge-std/console.sol";

contract BridgeAsset is Script {
    using OptionsBuilder for bytes;

    // Amount to bridge (0.1 ETH worth)
    uint256 constant BRIDGE_AMOUNT = 0.12 ether;

    function run() external {
        uint32 destinationEid =
            uint32(vm.parseUint(vm.prompt("Enter destination EID (e.g. 40255 for Fraxtal testnet):")));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address sender = vm.addr(deployerPrivateKey);
        address refundAddress = sender;

        console.log("Chain ID: %s", block.chainid);
        console.log("Sender: %s", sender);

        // Source chain ID
        uint256 sourceChainId = block.chainid;

        // Load deployment config
        string memory json =
            vm.readFile(string.concat("deployments/ynETHx-", vm.toString(sourceChainId), "-v0.0.1.json"));
        bytes memory holesky = vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId)));
        address oftAdapter = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapter")), (address)
        );

        vm.startBroadcast(deployerPrivateKey);

        // Get the ynETHx contract address
        address ynETHx = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".erc20Address")), (address)
        );

        {
            // Get the WETH contract address from ynETHx
            address weth = IERC4626(ynETHx).asset();

            // Deposit ETH to get WETH
            (bool success,) = weth.call{value: BRIDGE_AMOUNT}("");
            require(success, "ETH to WETH deposit failed");

            // Calculate amount of WETH needed to mint BRIDGE_AMOUNT of ynETHx
            uint256 wethAmount = BRIDGE_AMOUNT;

            // Approve WETH spending
            IERC20(weth).approve(ynETHx, wethAmount);

            // Deposit WETH to mint ynETHx using ERC4626 interface
            IERC4626(ynETHx).deposit(wethAmount, sender);
        }

        // Prepare bridge params
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam =
            SendParam(destinationEid, addressToBytes32(sender), BRIDGE_AMOUNT, BRIDGE_AMOUNT, options, "", "");

        // Get messaging fee
        MessagingFee memory fee = IOFT(oftAdapter).quoteSend(sendParam, false);

        // Approve ynETHx spending on OFT adapter
        IERC20(ynETHx).approve(oftAdapter, BRIDGE_AMOUNT);

        // Bridge tokens
        IOFT(oftAdapter).send{value: fee.nativeFee}(sendParam, fee, payable(refundAddress));

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
