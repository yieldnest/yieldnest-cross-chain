/* solhint-disable max-states-count */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {ILayerZeroEndpointV2} from
    "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Test} from "forge-std/Test.sol";

import {CREATE3Script} from "script/CREATE3Script.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract CrossChainBaseTest is Test, CREATE3Script {
    L1YnOFTAdapterUpgradeable public mainnetOFTAdapter;
    L2YnOFTAdapterUpgradeable public optimismOFTAdapter;
    L2YnOFTAdapterUpgradeable public arbitrumOFTAdapter;

    address public _deployer = makeAddr("deployer");
    address public _owner = makeAddr("owner");
    address public _controller = makeAddr("controller");

    ILayerZeroEndpointV2 public arbitrumLzEndpoint =
        ILayerZeroEndpointV2(0x1a44076050125825900e736c501f859c50fE728c);
    ILayerZeroEndpointV2 public optimismLzEndpoint =
        ILayerZeroEndpointV2(0x1a44076050125825900e736c501f859c50fE728c);
    ILayerZeroEndpointV2 public mainnetLzEndpoint =
        ILayerZeroEndpointV2(0x1a44076050125825900e736c501f859c50fE728c);

    ERC20Mock public mainnetERC20;
    L2YnERC20Upgradeable public optimismERC20;
    L2YnERC20Upgradeable public arbitrumERC20;

    uint256 public optimismFork;
    uint256 public arbitrumFork;
    uint256 public mainnetFork;

    uint32 public mainnetEid;
    uint32 public optimismEid;
    uint32 public arbitrumEid;

    function setUp() public virtual {
        // create forks
        optimismFork = vm.createFork(vm.envString("OPTIMISM_RPC_URL"));
        arbitrumFork = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));

        vm.selectFork(mainnetFork);
        mainnetEid = mainnetLzEndpoint.eid();

        vm.selectFork(optimismFork);
        optimismEid = optimismLzEndpoint.eid();

        vm.selectFork(arbitrumFork);
        arbitrumEid = arbitrumLzEndpoint.eid();

        RateLimiter.RateLimitConfig[] memory _rateLimitConfigs = new RateLimiter.RateLimitConfig[](3);
        _rateLimitConfigs[0] =
            RateLimiter.RateLimitConfig({dstEid: mainnetEid, limit: 1000000 ether, window: 1 days});
        _rateLimitConfigs[1] =
            RateLimiter.RateLimitConfig({dstEid: optimismEid, limit: 1000000 ether, window: 1 days});
        _rateLimitConfigs[2] =
            RateLimiter.RateLimitConfig({dstEid: arbitrumEid, limit: 1000000 ether, window: 1 days});

        vm.startPrank(_deployer);

        {
            vm.selectFork(mainnetFork);
            mainnetERC20 = new ERC20Mock("Test Token", "TEST");

            bytes32 mainnetOFTAdapterProxySalt = createSalt(_deployer, "OFTAdapterProxy");

            mainnetOFTAdapter = L1YnOFTAdapterUpgradeable(
                deployL1YnOFTAdapter(
                    mainnetOFTAdapterProxySalt,
                    address(mainnetERC20),
                    address(mainnetLzEndpoint),
                    _owner,
                    _controller
                )
            );
            vm.stopPrank();
            vm.prank(_owner);
            mainnetOFTAdapter.setRateLimits(_rateLimitConfigs);
            vm.startPrank(_deployer);
        }

        {
            vm.selectFork(optimismFork);
            bytes32 optimismERC20ProxySalt = createSalt(_deployer, "ERC20Proxy");
            optimismERC20 = L2YnERC20Upgradeable(
                deployL2YnERC20(optimismERC20ProxySalt, "Test Token", "TEST", 18, _owner, _controller)
            );
            bytes32 optimismOFTAdapterProxySalt = createSalt(_deployer, "OFTAdapterProxy");
            optimismOFTAdapter = L2YnOFTAdapterUpgradeable(
                deployL2YnOFTAdapter(
                    optimismOFTAdapterProxySalt,
                    address(optimismERC20),
                    address(optimismLzEndpoint),
                    _owner,
                    _controller
                )
            );
            vm.stopPrank();
            vm.prank(_owner);
            optimismOFTAdapter.setRateLimits(_rateLimitConfigs);
            vm.startPrank(_deployer);
        }

        {
            vm.selectFork(arbitrumFork);
            bytes32 arbitrumERC20ProxySalt = createSalt(_deployer, "ERC20Proxy");
            arbitrumERC20 = L2YnERC20Upgradeable(
                deployL2YnERC20(arbitrumERC20ProxySalt, "Test Token", "TEST", 18, _owner, _controller)
            );
            bytes32 arbitrumOFTAdapterProxySalt = createSalt(_deployer, "OFTAdapterProxy");
            arbitrumOFTAdapter = L2YnOFTAdapterUpgradeable(
                deployL2YnOFTAdapter(
                    arbitrumOFTAdapterProxySalt,
                    address(arbitrumERC20),
                    address(arbitrumLzEndpoint),
                    _owner,
                    _controller
                )
            );
            vm.stopPrank();
            vm.prank(_owner);
            arbitrumOFTAdapter.setRateLimits(_rateLimitConfigs);
            vm.startPrank(_deployer);
        }
        vm.stopPrank();

        vm.startPrank(_owner);
        vm.selectFork(optimismFork);
        optimismERC20.grantRole(optimismERC20.MINTER_ROLE(), address(optimismOFTAdapter));

        vm.selectFork(arbitrumFork);
        arbitrumERC20.grantRole(arbitrumERC20.MINTER_ROLE(), address(arbitrumOFTAdapter));
        vm.stopPrank();
    }

    function createSalt(address deployerAddress, string memory label) public pure returns (bytes32 _salt) {
        _salt = bytes32(abi.encodePacked(bytes20(deployerAddress), bytes12(keccak256(bytes(label)))));
    }
}
