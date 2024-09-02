// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiChainDeployer} from "@factory/MultiChainDeployer.sol";
import {IMintableBurnableERC20} from "@interfaces/IMintableBurnableERC20.sol";
import {L1YnOFTAdapterUpgradeable} from "@adapters/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@adapters/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@adapters/L2YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

/**
 * @notice Rate Limit Configuration struct.
 * @param dstEid The destination endpoint id.
 * @param limit This represents the maximum allowed amount within a given window.
 * @param window Defines the duration of the rate limiting window.
 */
struct RateLimitConfig {
    uint32 dstEid;
    uint256 limit;
    uint256 window;
}

contract CrossChainBaseTest is Test {
    MultiChainDeployer public mainnetDeployer;
    MultiChainDeployer public optimismDeployer;
    MultiChainDeployer public baseDeployer;
    MultiChainDeployer public arbitrumDeployer;
    MultiChainDeployer public fraxDeployer;
    L1YnOFTAdapterUpgradeable public l1OFTAdapter;
    L2YnERC20Upgradeable public l2YnERC20;
    L2YnOFTAdapterUpgradeable public l2OFTAdapter;

    address deployer = address(0xDeadCe11);

    function setUp() public {
        // create forks
        uint256 optimismFork = vm.createFork("OPTIMISM_RPC_URL");
        uint256 baseFork = vm.createFork("BASE_RPC_URL");
        uint256 arbitrumFork = vm.createFork("ARBITRUM_RPC_URL");
        uint256 fraxFork = vm.createFork("FRAX_RPC_URL");
        uint256 mainnetFork = vm.createFork("MAINNET_RPC_URL");
        uint256 holeskyFork = vm.createFork("HOLESKY_RPC_URL");

        vm.selectFork(mainnetFork);
        mainnetDeployer = new MultiChainDeployer();

        vm.selectFork(baseFork);
        baseDeployer = new MultiChainDeployer();

        vm.selectFork(optimisFork);
        optimisDeployer = new MultiChainDeployer();

        vm.selectFork(arbitrumFork);
        arbitrumDeployer = new MultiChainDeployer();

        vm.selectFork(fraxFork);
        fraxDeployer = new MultiChainDeployer();

        bytes memory contractByteCode = type(L1YnOFTAdapterUpgradeable).creationCode;

        // create salt where first 20 bytes matches the deployer address
        bytes32 salt = abi.encodePacked(bytes20(deployer), bytes12(1));
        RateLimiter.RateLimitConfig[] memory _rateLimitConfigs = new RateLimiter.RateLimitConfig[](1);

        RateLimiter.RateLimitConfig memory limitConfig =
            RateLimiter.RateLimitConfig({dstEid: uint32(1), limit: 1 ether, window: 1 days});

        _rateLimitConfigs[0] = limitConfig;

        vm.startPrank(deployer);
        vm.selectFork(mainnetFork);

        l1oftAdapter =
            L1YnOFTAdapterUpgradeable(mainnetDeployer.deployOFTAdapter(salt, creationCode, _rateLimitConfigs));
    }
}
