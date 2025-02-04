// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IOFT, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {Script} from "forge-std/Script.sol";

import {console} from "forge-std/console.sol";

contract BridgeAsset is Script {
    using OptionsBuilder for bytes;

    // Fraxtal testnet EID
    uint32 constant DST_EID = 40255;

    // Amount to bridge (0.1 ETH worth)
    uint256 constant BRIDGE_AMOUNT = 0.1 ether;

    function run() external {
        // Load deployment config
        string memory json = vm.readFile("deployments/ynETHx-17000-v0.0.1.json");
        bytes memory holesky = vm.parseJson(json, ".chains.17000");
        address oftAdapter = abi.decode(vm.parseJson(json, ".chains.17000.oftAdapter"), (address));
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address sender = vm.addr(deployerPrivateKey);
        address refundAddress = sender;

        vm.startBroadcast(deployerPrivateKey);

        // Prepare bridge params
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam =
            SendParam(DST_EID, addressToBytes32(sender), BRIDGE_AMOUNT, BRIDGE_AMOUNT, options, "", "");

        // Get messaging fee
        MessagingFee memory fee = IOFT(oftAdapter).quoteSend(sendParam, false);

        // Bridge tokens
        IOFT(oftAdapter).send{value: fee.nativeFee}(sendParam, fee, payable(refundAddress));

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
