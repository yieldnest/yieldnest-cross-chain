// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiChainDeployer} from "@factory/MultiChainDeployer.sol";
import {IMintableBurnableERC20} from "@interfaces/IMintableBurnableERC20.sol";
import {L1YnOFTAdapterUpgradeable} from "@adapters/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@adapters/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@adapters/L2YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {ERC20Mock} from "@layerzerolabs/lz-evm-oapp-v2/test/mocks/ERC20Mock.sol";
import "forge-std/console.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract CrossChainBaseTest is Test {
    MultiChainDeployer public mainnetDeployer;
    MultiChainDeployer public optimismDeployer;
    MultiChainDeployer public arbitrumDeployer;
    // MultiChainDeployer public baseDeployer;
    // MultiChainDeployer public fraxDeployer;

    L1YnOFTAdapterUpgradeable public mainnetOFTAdapter;
    L2YnOFTAdapterUpgradeable public optimismOFTAdapter;
    L2YnOFTAdapterUpgradeable public arbitrumOFTAdapter;

    address public _deployer = makeAddr("deployer");

    address public arbitrumLzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    address public optimismLzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    address public mainnetLzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);

    ERC20Mock public mainnetERC20;
    L2YnERC20Upgradeable public optimismERC20;
    L2YnERC20Upgradeable public arbitrumERC20;

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

        RateLimiter.RateLimitConfig[] memory _rateLimitConfigs = new RateLimiter.RateLimitConfig[](1);
        _rateLimitConfigs[0] = RateLimiter.RateLimitConfig({dstEid: uint32(1), limit: 1 ether, window: 1 days});

        vm.startPrank(_deployer);

        {
            vm.selectFork(mainnetFork);
            mainnetDeployer = new MultiChainDeployer{salt: "SALT"}();
            mainnetERC20 = new ERC20Mock("Test Token", "TEST");
            address mainnetOFTAdapterImpl =
                address(new L1YnOFTAdapterUpgradeable(address(mainnetERC20), mainnetLzEndpoint));
            mainnetOFTAdapter = L1YnOFTAdapterUpgradeable(
                address(new TransparentUpgradeableProxy(mainnetOFTAdapterImpl, _deployer, ""))
            );
            mainnetOFTAdapter.initialize(_deployer, _rateLimitConfigs);
        }

        {
            vm.selectFork(optimismFork);
            optimismDeployer = new MultiChainDeployer{salt: "SALT"}();
            bytes32 optimismERC20Salt = createSalt(_deployer, "ERC20");
            bytes32 optimismERC20ProxySalt = createSalt(_deployer, "ERC20Proxy");
            optimismERC20 = L2YnERC20Upgradeable(
                optimismDeployer.deployL2YnERC20(
                    optimismERC20Salt, optimismERC20ProxySalt, "Test Token", "TEST", _deployer
                )
            );
            bytes32 optimismOFTAdapterSalt = createSalt(_deployer, "OFTAdapter");
            bytes32 optimismOFTAdapterProxySalt = createSalt(_deployer, "OFTAdapterProxy");
            optimismOFTAdapter = L2YnOFTAdapterUpgradeable(
                optimismDeployer.deployL2YnOFTAdapter(
                    optimismOFTAdapterSalt,
                    optimismOFTAdapterProxySalt,
                    address(optimismERC20),
                    optimismLzEndpoint,
                    _deployer,
                    _rateLimitConfigs
                )
            );
        }

        {
            vm.selectFork(arbitrumFork);
            arbitrumDeployer = new MultiChainDeployer{salt: "SALT"}();
            bytes32 arbitrumERC20Salt = createSalt(_deployer, "ERC20");
            bytes32 arbitrumERC20ProxySalt = createSalt(_deployer, "ERC20Proxy");
            arbitrumERC20 = L2YnERC20Upgradeable(
                arbitrumDeployer.deployL2YnERC20(
                    arbitrumERC20Salt, arbitrumERC20ProxySalt, "Test Token", "TEST", _deployer
                )
            );
            bytes32 arbitrumOFTAdapterSalt = createSalt(_deployer, "OFTAdapter");
            bytes32 arbitrumOFTAdapterProxySalt = createSalt(_deployer, "OFTAdapterProxy");
            arbitrumOFTAdapter = L2YnOFTAdapterUpgradeable(
                arbitrumDeployer.deployL2YnOFTAdapter(
                    arbitrumOFTAdapterSalt,
                    arbitrumOFTAdapterProxySalt,
                    address(arbitrumERC20),
                    arbitrumLzEndpoint,
                    _deployer,
                    _rateLimitConfigs
                )
            );
        }

        // vm.selectFork(baseFork);
        // baseDeployer = new MultiChainDeployer();

        // vm.selectFork(fraxFork);
        // fraxDeployer = new MultiChainDeployer();

        vm.stopPrank();
    }

    function createSalt(address deployerAddress, string memory label) public pure returns (bytes32 _salt) {
        _salt = bytes32(abi.encodePacked(bytes20(deployerAddress), bytes12(keccak256(bytes(label)))));
    }
}
