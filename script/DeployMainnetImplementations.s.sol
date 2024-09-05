// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

//forge script script/DeployMainnetImplementations.s.sol:DeployMainnetImplementations --rpc-url ${rpc} --account ${deployerAccountName} --sender ${deployer} --broadcast --etherscan-api-key ${api} --verify
contract DeployMainnetImplementations is Script {
    RateLimiter.RateLimitConfig[] public _rateLimitConfigs;

    function setUp() public {}

    function run(string memory __path) public {
        vm.broadcast();

        mainnetOFTAdapterImpl = address(
            new L1YnOFTAdapterUpgradeable(address(vm.envAddress("YnERC20_ADDRESS")), address("MIANNET_LZ_ENDPOINT"))
        );
        mainnetOFTAdapter =
            L1YnOFTAdapterUpgradeable(address(new TransparentUpgradeableProxy(mainnetOFTAdapterImpl, msg.sender, "")));
        mainnetOFTAdapter.initialize(msg.sender, _rateLimitConfigs);
    }
}
