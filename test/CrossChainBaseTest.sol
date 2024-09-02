// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiChainDeployer} from "@factory/MultiChainDeployer.sol";
import {IMintableBurnableERC20} from "@interfaces/IMintableBurnableERC20.sol";
import {L1YnOFTAdapterUpgradeable} from "@adapters/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@adapters/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@adapters/L2YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import "forge-std/console.sol";

contract CrossChainBaseTest is Test {
    MultiChainDeployer public mainnetDeployer;
    MultiChainDeployer public optimismDeployer;
    MultiChainDeployer public baseDeployer;
    MultiChainDeployer public arbitrumDeployer;
    MultiChainDeployer public fraxDeployer;

    L1YnOFTAdapterUpgradeable public l1OFTAdapter;
    L2YnERC20Upgradeable public l2YnERC20;
    L2YnOFTAdapterUpgradeable public l2OFTAdapter;

    address public _deployer = address(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f);

    uint256 optimismFork;
    uint256 arbitrumFork;
    uint256 mainnetFork;
    // uint256 holeskyFork;
    // uint256 fraxFork;
    // uint256 baseFork;

    function setUp() public {
        // create forks
        optimismFork = vm.createFork(vm.envString("OPTIMISM_RPC_URL"));
        arbitrumFork = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        // holeskyFork = vm.createFork(vm.envString("HOLESKY_RPC_URL"));
        // fraxFork = vm.createFork(vm.envString("FRAX_RPC_URL"));
        // baseFork = vm.createFork(vm.envString("BASE_RPC_URL"));

        vm.selectFork(mainnetFork);
        mainnetDeployer = new MultiChainDeployer();

        vm.selectFork(optimismFork);
        optimismDeployer = new MultiChainDeployer();

        vm.selectFork(arbitrumFork);
        arbitrumDeployer = new MultiChainDeployer();

        // vm.selectFork(baseFork);
        // baseDeployer = new MultiChainDeployer();

        // vm.selectFork(fraxFork);
        // fraxDeployer = new MultiChainDeployer();

        bytes memory contractByteCode = type(L1YnOFTAdapterUpgradeable).creationCode;

        // create salt where first 20 bytes matches the deployer address
        bytes32 salt = createSalt(_deployer);

        RateLimiter.RateLimitConfig[] memory _rateLimitConfigs = new RateLimiter.RateLimitConfig[](1);

        RateLimiter.RateLimitConfig memory limitConfig =
            RateLimiter.RateLimitConfig({dstEid: uint32(1), limit: 1 ether, window: 1 days});

        _rateLimitConfigs[0] = limitConfig;

        vm.selectFork(mainnetFork);
        vm.startPrank(_deployer);
        l1OFTAdapter =
            L1YnOFTAdapterUpgradeable(mainnetDeployer.deployOFTAdapter(salt, contractByteCode, _rateLimitConfigs));
        vm.stopPrank();
    }

    function createSalt(address deployerAddress) public pure returns (bytes32 _salt) {
        _salt = bytes32(abi.encodePacked(bytes20(deployerAddress), bytes12("testing_test")));
    }
}
