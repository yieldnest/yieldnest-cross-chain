// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseData} from "../BaseData.s.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {console} from "forge-std/console.sol";

/**
 * @notice This script prints the ynETHx balance for the current chain
 *
 * Usage:
 * ```
 * forge script script/commands/PrintAssetBalance.s.sol:PrintAssetBalance --rpc-url <RPC_URL>
 * ```
 */
contract PrintAssetBalance is BaseData {
    function run() external view {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(deployerPrivateKey);

        // Source chain ID
        // If we're on Fraxtal testnet (2522), Morph testnet (2810), or Holesky (17000),
        // use Holesky (17000) as the source chain since it's the L1 testnet.
        // Otherwise default to Ethereum mainnet (1)
        uint256 sourceChainId = block.chainid;
        uint256 baseChainId = sourceChainId == 2522 || sourceChainId == 2810 || sourceChainId == 17000 ? 17000 : 1;

        // Load deployment config
        string memory json =
            vm.readFile(string.concat("deployments/ynETHx-", vm.toString(baseChainId), "-v0.0.4.json"));

        // Get the ynETHx contract address
        address ynETHx = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".erc20Address")), (address)
        );

        // Get ynETHx balance
        uint256 balance = IERC20(ynETHx).balanceOf(sender);

        console.log("Chain ID: %s", block.chainid);
        console.log("Address: %s", sender);
        console.log("ynETHx Balance: %s", balance);
    }
}
