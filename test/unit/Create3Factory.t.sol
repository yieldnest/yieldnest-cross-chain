/* solhint-disable gas-custom-errors, check-send-result */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {ILayerZeroEndpointV2} from
    "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Test} from "forge-std/Test.sol";
import {Test} from "forge-std/Test.sol";
import {BaseScript} from "script/BaseScript.s.sol";
import {CREATE3Factory} from "src/factory/CREATE3Factory.sol";
import {ImmutableMultiChainDeployer} from "src/factory/ImmutableMultiChainDeployer.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {L1OFTAdapterMock} from "test/mocks/L1OFTAdapterMock.sol";
import {L2OFTAdapterMock} from "test/mocks/L2OFTAdapterMock.sol";
import {CrossChainBaseTest} from "test/unit/CrossChainBaseTest.t.sol";

interface IMockOFTAdapter {
    function mock() external returns (uint256);
}

contract TestFactoryDeployment is CrossChainBaseTest {
    uint32 public hemiEid;
    uint256 public hemiFork;
    ImmutableMultiChainDeployer public hemiDeployer;
    L2YnERC20Upgradeable public hemiERC20;
    address public hemiOFTAdapterImpl;
    L2YnOFTAdapterUpgradeable public hemiOFTAdapter;
    ILayerZeroEndpointV2 public hemiLzEndpoint = ILayerZeroEndpointV2(0x6F475642a6e85809B1c36Fa62763669b1b48DD5B);

    function setUp() public virtual override {
        super.setUp();
        hemiFork = vm.createFork(vm.envString("HEMI_RPC_URL"));

        vm.selectFork(hemiFork);
        hemiEid = hemiLzEndpoint.eid();

        RateLimiter.RateLimitConfig[] memory _rateLimitConfigs = new RateLimiter.RateLimitConfig[](4);
        _rateLimitConfigs[0] =
            RateLimiter.RateLimitConfig({dstEid: mainnetEid, limit: 1000000 ether, window: 1 days});
        _rateLimitConfigs[1] =
            RateLimiter.RateLimitConfig({dstEid: optimismEid, limit: 1000000 ether, window: 1 days});
        _rateLimitConfigs[2] =
            RateLimiter.RateLimitConfig({dstEid: arbitrumEid, limit: 1000000 ether, window: 1 days});
        _rateLimitConfigs[3] = RateLimiter.RateLimitConfig({dstEid: hemiEid, limit: 1000000 ether, window: 1 days});

        vm.startPrank(_deployer);
        hemiDeployer = new ImmutableMultiChainDeployer{salt: "SALT"}();
        bytes32 hemiERC20Salt = createSalt(_deployer, "ERC20");
        bytes32 hemiERC20ProxySalt = createSalt(_deployer, "ERC20Proxy");
        hemiERC20 = L2YnERC20Upgradeable(
            hemiDeployer.deployL2YnERC20(
                hemiERC20Salt, hemiERC20ProxySalt, "Test Token", "TEST", 18, _owner, _controller, l2YnERC20ByteCode
            )
        );
        bytes32 hemiOFTAdapterSalt = createSalt(_deployer, "OFTAdapter");
        bytes32 hemiOFTAdapterProxySalt = createSalt(_deployer, "OFTAdapterProxy");
        hemiOFTAdapter = L2YnOFTAdapterUpgradeable(
            hemiDeployer.deployL2YnOFTAdapter(
                hemiOFTAdapterSalt,
                hemiOFTAdapterProxySalt,
                address(hemiERC20),
                address(hemiLzEndpoint),
                _owner,
                _controller,
                l2YnOFTAdapterByteCode
            )
        );
        vm.stopPrank();
        vm.prank(_owner);
        hemiOFTAdapter.setRateLimits(_rateLimitConfigs);
    }

    function test_Deploy_Create3Factory() public {
        vm.selectFork(mainnetFork);

        vm.startPrank(_deployer);
        bytes32 salt = createSalt(_deployer, "create3factory");

        bytes memory _contractCode = abi.encodePacked(type(CREATE3Factory).creationCode);

        address deployedMainnetFactory = mainnetDeployer.deploy(salt, _contractCode);

        assertNotEq(deployedMainnetFactory, address(0), "Factory should be deployed");

        vm.selectFork(hemiFork);
        address deployedHemiFactory = hemiDeployer.deploy(salt, _contractCode);

        assertEq(deployedHemiFactory, deployedMainnetFactory, "Factories should be the same");

        // deploy ynethx on hemi through the create3 factory
    }
}
