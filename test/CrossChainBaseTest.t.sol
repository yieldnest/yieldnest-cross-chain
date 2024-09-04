// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {LZEndpointMock} from "./mocks/LZEndpointMock.sol";
// import {TestHelper} from "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import {IMintableBurnableERC20} from "@interfaces/IMintableBurnableERC20.sol";
import {L1YnOFTAdapterUpgradeable} from "@adapters/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@adapters/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@adapters/L2YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {ERC20Mock} from "@layerzerolabs/lz-evm-oapp-v2/test/mocks/ERC20Mock.sol";
import {EndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/EndpointV2.sol";
import {TestHelper} from "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";
import "forge-std/console.sol";

contract CrossChainBaseTest is TestHelper {
    ImmutableMultiChainDeployer public mainnetDeployer;
    ImmutableMultiChainDeployer public optimismDeployer;
    ImmutableMultiChainDeployer public arbitrumDeployer;
    // ImmutableMultiChainDeployer public baseDeployer;
    // ImmutableMultiChainDeployer public fraxDeployer;

    L1YnOFTAdapterUpgradeable public mainnetOFTAdapter;
    L2YnOFTAdapterUpgradeable public optimismOFTAdapter;
    L2YnOFTAdapterUpgradeable public arbitrumOFTAdapter;

    address public _deployer = makeAddr("deployer");
    address public _owner = makeAddr("owner");
    address public _controller = makeAddr("controller");

    EndpointV2 public arbitrumLzEndpoint = EndpointV2(0x1a44076050125825900e736c501f859c50fE728c);
    EndpointV2 public optimismLzEndpoint = EndpointV2(0x1a44076050125825900e736c501f859c50fE728c);
    EndpointV2 public mainnetLzEndpoint = EndpointV2(0x1a44076050125825900e736c501f859c50fE728c);

    ERC20Mock public mainnetERC20;
    // LZEndpointMock public mainnetLZEndpoint;
    // LZEndpointMock public optimismLZEndpoint;
    // LZEndpointMock public arbitrumLzEndpoint;
    L2YnERC20Upgradeable public optimismERC20;
    L2YnERC20Upgradeable public arbitrumERC20;

    address mainnetOFTAdapterImpl;

    uint256 optimismFork;
    uint256 arbitrumFork;
    uint256 mainnetFork;

    uint32 mainnetEid;
    uint32 optimismEid;
    uint32 arbitrumEid;

    // uint256 holeskyFork;
    // uint256 fraxFork;
    // uint256 baseFork;

    function setUp() public virtual override {
        // create forks
        optimismFork = vm.createFork(vm.envString("OPTIMISM_RPC_URL"), 124909408);
        arbitrumFork = vm.createFork(vm.envString("ARBITRUM_RPC_URL"), 249855816);
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 20674289);
        // holeskyFork = vm.createFork(vm.envString("HOLESKY_RPC_URL"), 2266061);
        // fraxFork = vm.createFork(vm.envString("FRAX_RPC_URL"), 9303466);
        // baseFork = vm.createFork(vm.envString("BASE_RPC_URL"), 19314154);

        // mainnetLZEndpoint = new LZEndpointMock(1);
        // optimismLZEndpoint = new LZEndpointMock(10);
        // arbitrumLzEndpoint = new LZEndpointMock(42161);
        vm.selectFork(mainnetFork);
        mainnetEid = mainnetLzEndpoint.eid();

        vm.selectFork(optimismFork);
        optimismEid = optimismLzEndpoint.eid();

        vm.selectFork(arbitrumFork);
        arbitrumEid = arbitrumLzEndpoint.eid();

        RateLimiter.RateLimitConfig[] memory _rateLimitConfigs = new RateLimiter.RateLimitConfig[](2);
        _rateLimitConfigs[0] = RateLimiter.RateLimitConfig({dstEid: optimismEid, limit: 1000000 ether, window: 1 days});
        _rateLimitConfigs[1] = RateLimiter.RateLimitConfig({dstEid: arbitrumEid, limit: 1000000 ether, window: 1 days});

        vm.startPrank(_deployer);

        {
            vm.selectFork(mainnetFork);
            mainnetDeployer = new ImmutableMultiChainDeployer{salt: "SALT"}();
            mainnetERC20 = new ERC20Mock("Test Token", "TEST");
            mainnetOFTAdapterImpl =
                address(new L1YnOFTAdapterUpgradeable(address(mainnetERC20), address(mainnetLzEndpoint)));
            mainnetOFTAdapter = L1YnOFTAdapterUpgradeable(
                address(new TransparentUpgradeableProxy(mainnetOFTAdapterImpl, _controller, ""))
            );
            mainnetOFTAdapter.initialize(_owner, _rateLimitConfigs);
        }

        {
            vm.selectFork(optimismFork);
            optimismDeployer = new ImmutableMultiChainDeployer{salt: "SALT"}();
            bytes32 optimismERC20Salt = createSalt(_deployer, "ERC20");
            bytes32 optimismERC20ProxySalt = createSalt(_deployer, "ERC20Proxy");
            optimismERC20 = L2YnERC20Upgradeable(
                optimismDeployer.deployL2YnERC20(
                    optimismERC20Salt, optimismERC20ProxySalt, "Test Token", "TEST", _owner, _controller
                )
            );
            bytes32 optimismOFTAdapterSalt = createSalt(_deployer, "OFTAdapter");
            bytes32 optimismOFTAdapterProxySalt = createSalt(_deployer, "OFTAdapterProxy");
            _rateLimitConfigs[0] =
                RateLimiter.RateLimitConfig({dstEid: mainnetEid, limit: 1000000 ether, window: 1 days});
            _rateLimitConfigs[1] =
                RateLimiter.RateLimitConfig({dstEid: arbitrumEid, limit: 1000000 ether, window: 1 days});
            optimismOFTAdapter = L2YnOFTAdapterUpgradeable(
                optimismDeployer.deployL2YnOFTAdapter(
                    optimismOFTAdapterSalt,
                    optimismOFTAdapterProxySalt,
                    address(optimismERC20),
                    address(optimismLzEndpoint),
                    _owner,
                    _rateLimitConfigs,
                    _controller
                )
            );
        }

        {
            vm.selectFork(arbitrumFork);
            arbitrumDeployer = new ImmutableMultiChainDeployer{salt: "SALT"}();
            bytes32 arbitrumERC20Salt = createSalt(_deployer, "ERC20");
            bytes32 arbitrumERC20ProxySalt = createSalt(_deployer, "ERC20Proxy");
            arbitrumERC20 = L2YnERC20Upgradeable(
                arbitrumDeployer.deployL2YnERC20(
                    arbitrumERC20Salt, arbitrumERC20ProxySalt, "Test Token", "TEST", _owner, _controller
                )
            );
            bytes32 arbitrumOFTAdapterSalt = createSalt(_deployer, "OFTAdapter");
            bytes32 arbitrumOFTAdapterProxySalt = createSalt(_deployer, "OFTAdapterProxy");
            _rateLimitConfigs[0] =
                RateLimiter.RateLimitConfig({dstEid: mainnetEid, limit: 1000000 ether, window: 1 days});
            _rateLimitConfigs[1] =
                RateLimiter.RateLimitConfig({dstEid: optimismEid, limit: 1000000 ether, window: 1 days});
            arbitrumOFTAdapter = L2YnOFTAdapterUpgradeable(
                arbitrumDeployer.deployL2YnOFTAdapter(
                    arbitrumOFTAdapterSalt,
                    arbitrumOFTAdapterProxySalt,
                    address(arbitrumERC20),
                    address(arbitrumLzEndpoint),
                    _owner,
                    _rateLimitConfigs,
                    _controller
                )
            );
        }

        endpoints[mainnetEid] = address(mainnetLzEndpoint);
        endpoints[optimismEid] = address(optimismLzEndpoint);
        endpoints[arbitrumEid] = address(arbitrumLzEndpoint);

        // vm.selectFork(baseFork);
        // baseDeployer = new ImmutableMultiChainDeployer();

        // vm.selectFork(fraxFork);
        // fraxDeployer = new ImmutableMultiChainDeployer();

        vm.stopPrank();
    }

    function createSalt(address deployerAddress, string memory label) public pure returns (bytes32 _salt) {
        _salt = bytes32(abi.encodePacked(bytes20(deployerAddress), bytes12(keccak256(bytes(label)))));
    }
}
