// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {OFTAdapterUpgradeable} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/OFTAdapterUpgradeable.sol";
import "forge-std/console.sol";

// forge script script/SetPeersOFTAdapter.s.sol:SetPeersOFTAdapter --rpc-url ${rpc} --sig "run(string calldata)" ${path} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify

contract SetPeersOFTAdapter is BaseScript {
    OFTAdapterUpgradeable public oftAdapter;

    function run(string calldata _jsonPath) public {
        _loadInput(_jsonPath);

        if (currentDeployment.oftAdapter == address(0)) {
            console.log("OFT Adapter not deployed yet");
            return;
        }

        oftAdapter = OFTAdapterUpgradeable(currentDeployment.oftAdapter);

        for (uint256 i = 0; i < deployment.chains.length; i++) {
            if (deployment.chains[i].chainId == block.chainid) {
                continue;
            }
            uint32 eid = deployment.chains[i].lzEID;
            address adapter = deployment.chains[i].oftAdapter;
            bytes32 adapterBytes32 = addressToBytes32(adapter);
            if (oftAdapter.peers(eid) == adapterBytes32) {
                console.log("Adapter already set for chain %d", deployment.chains[i].chainId);
                continue;
            }

            vm.broadcast();
            oftAdapter.setPeer(eid, adapterBytes32);
        }

        _saveDeployment();
    }
}
