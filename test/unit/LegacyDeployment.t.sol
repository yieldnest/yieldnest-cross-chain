/* solhint-disable gas-custom-errors, check-send-result */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable as LegacyL2YnERC20Upgradeable} from "@/legacy/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable as LegacyL2YnOFTAdapterUpgradeable} from "@/legacy/L2YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {ILayerZeroEndpointV2} from
    "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Test} from "forge-std/Test.sol";
import {Test} from "forge-std/Test.sol";

import {console2} from "forge-std/console2.sol";
import {ImmutableMultiChainDeployer as LegacyImmutableMultiChainDeployer} from
    "src/legacy/ImmutableMultiChainDeployer.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {L1OFTAdapterMock} from "test/mocks/L1OFTAdapterMock.sol";
import {L2OFTAdapterMock} from "test/mocks/L2OFTAdapterMock.sol";
import {CrossChainBaseTest} from "test/unit/CrossChainBaseTest.t.sol";

interface IMockOFTAdapter {
    function mock() external returns (uint256);
}

contract TestLegacyDeployment is CrossChainBaseTest {
    uint32 public hemiEid;
    uint256 public hemiFork;
    LegacyImmutableMultiChainDeployer public hemiDeployer;
    LegacyL2YnERC20Upgradeable public hemiERC20;
    address public hemiOFTAdapterImpl;
    LegacyL2YnOFTAdapterUpgradeable public hemiOFTAdapter;
    ILayerZeroEndpointV2 public hemiLzEndpoint = ILayerZeroEndpointV2(0x6F475642a6e85809B1c36Fa62763669b1b48DD5B);

    address public correctERC20Address = 0xE231DB5F348d709239Ef1741EA30961B3B635a61;
    address public correctLegacyDeployerAddress = 0xDE21c853BA39e77251a90dBB0b4C3d94463EbCfA;
    address public deployerAddress = address(0x4C51Ce7B2546e18449fbE16738A8D55bc195a4dd);

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

        vm.startPrank(deployerAddress);

        bytes32 deployerSalt = createLegacySalt(deployerAddress, "MultiChainDeployer");
        hemiDeployer = new LegacyImmutableMultiChainDeployer{salt: deployerSalt}();
        bytes32 hemiERC20Salt = createLegacySalt(deployerAddress, "L2YnERC20");
        bytes32 hemiERC20ProxySalt = createLegacySalt(deployerAddress, "L2YnERC20Proxy");
        bytes memory _l2YnERC20UpgradeableByteCode = type(LegacyL2YnERC20Upgradeable).creationCode;

        hemiERC20 = LegacyL2YnERC20Upgradeable(
            hemiDeployer.deployL2YnERC20(
                hemiERC20Salt,
                hemiERC20ProxySalt,
                "Test Token",
                "TEST",
                _owner,
                _controller,
                _l2YnERC20UpgradeableByteCode
            )
        );
        /**
         * bytes32 _implSalt,
         *     bytes32 _proxySalt,
         *     string calldata _name,
         *     string calldata _symbol,
         *     address _owner,
         *     address _proxyController,
         *     bytes memory _l2YnERC20UpgradeableByteCode
         */
        bytes32 hemiOFTAdapterSalt = createLegacySalt(deployerAddress, "L2YnOFTAdapter");
        bytes32 hemiOFTAdapterProxySalt = createLegacySalt(deployerAddress, "L2YnOFTAdapterProxy");

        // deploy oft adapter implementation and proxu with deploy function rather than deployL2YnOFTAdapter
        bytes memory _oftAdapterBytecode = abi.encodePacked(type(LegacyL2YnOFTAdapterUpgradeable).creationCode);
        bytes memory _oftAdapterConstructorParams = abi.encode(address(hemiERC20), address(hemiLzEndpoint));
        // address oftAdapterImplementation = hemiDeployer.deploy(hemiOFTAdapterImplementationSalt,
        // _oftAdapterBytecode);
        // address oftAdapterImpl = hemiDeployer.deploy(hemiOFTAdapterImplementationSalt, _oftAdapterBytecode);

        hemiOFTAdapter = LegacyL2YnOFTAdapterUpgradeable(
            hemiDeployer.deployL2YnOFTAdapter(
                hemiOFTAdapterSalt,
                hemiOFTAdapterProxySalt,
                address(hemiERC20),
                address(hemiLzEndpoint),
                deployerAddress,
                _controller,
                _oftAdapterBytecode
            )
        );

        // hemiOFTAdapter.initialize(address(hemiERC20), address(hemiLzEndpoint), _owner, _controller);
        hemiOFTAdapter.setRateLimits(_rateLimitConfigs);
        console2.log("hemiOFTAdapter", address(hemiOFTAdapter));
    }

    function test_hemi_deploy_create3factory() public view {
        assertEq(address(hemiDeployer), address(correctLegacyDeployerAddress), "hemiDeployer should be deployed");
        assertEq(address(hemiERC20), address(correctERC20Address), "hemiERC20 should be deployed");
        assertEq(address(hemiOFTAdapter), address(optimismOFTAdapter), "hemiOFTAdapter should be deployed");
    }

    function createLegacySalt(
        address _deployerAddress,
        string memory _label
    )
        internal
        view
        returns (bytes32 _salt)
    {
        _salt = bytes32(
            abi.encodePacked(
                bytes20(_deployerAddress), bytes12(bytes32(keccak256(abi.encode(_label, "ynETHx", "v0.0.1"))))
            )
        );
    }
}
