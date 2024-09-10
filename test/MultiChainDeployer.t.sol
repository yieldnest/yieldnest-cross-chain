// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrossChainBaseTest} from "./CrossChainBaseTest.t.sol";

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import {IMintableBurnableERC20} from "@interfaces/IMintableBurnableERC20.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

contract Test_ImmutableMultiChainDeployer is CrossChainBaseTest {
    function test_Deployment() public view {
        assertEq(address(arbitrumDeployer), address(optimismDeployer));
        assertNotEq(address(mainnetERC20), address(0));
        assertNotEq(address(mainnetOFTAdapter), address(0));
        assertNotEq(address(arbitrumERC20), address(0));
        assertNotEq(address(arbitrumOFTAdapter), address(0));
        assertEq(address(arbitrumERC20), address(optimismERC20));
        assertEq(address(arbitrumOFTAdapter), address(optimismOFTAdapter));
    }

    function test_Deploy_MsgSenderNotInSalt_Revert() public {
        vm.selectFork(arbitrumFork);

        RateLimiter.RateLimitConfig[] memory _rateLimitConfigs = new RateLimiter.RateLimitConfig[](1);
        _rateLimitConfigs[0] = RateLimiter.RateLimitConfig({dstEid: uint32(1), limit: 1 ether, window: 1 days});

        vm.expectRevert(ImmutableMultiChainDeployer.InvalidSalt.selector);
        address(
            arbitrumDeployer.deployL2YnOFTAdapter(
                keccak256(abi.encode("test")),
                keccak256(abi.encode("proxySalt")),
                address(arbitrumERC20),
                address(arbitrumLzEndpoint),
                _owner,
                _rateLimitConfigs,
                _controller,
                l2YnOFTAdapterByteCode
            )
        );
    }

    function test_Deploy_AlreadyDeployed_Revert() public {
        vm.selectFork(arbitrumFork);

        bytes32 arbitrumOFTAdapterSalt = createSalt(_deployer, "OFTAdapter");
        bytes32 arbitrumOFTAdapterProxySalt = createSalt(_deployer, "OFTAdapterProxy");

        RateLimiter.RateLimitConfig[] memory _rateLimitConfigs = new RateLimiter.RateLimitConfig[](1);
        _rateLimitConfigs[0] = RateLimiter.RateLimitConfig({dstEid: uint32(1), limit: 1 ether, window: 1 days});

        vm.expectRevert(ImmutableMultiChainDeployer.AlreadyDeployed.selector);
        vm.prank(_deployer);

        arbitrumDeployer.deployL2YnOFTAdapter(
            arbitrumOFTAdapterSalt,
            arbitrumOFTAdapterProxySalt,
            address(arbitrumERC20),
            address(arbitrumLzEndpoint),
            _owner,
            _rateLimitConfigs,
            _controller,
            l2YnOFTAdapterByteCode
        );
    }
}
