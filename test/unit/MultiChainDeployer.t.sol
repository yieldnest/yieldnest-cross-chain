// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrossChainBaseTest} from "./CrossChainBaseTest.t.sol";

import {ImmutableMultiChainDeployer} from "@/factory/ImmutableMultiChainDeployer.sol";
import {CREATE3Factory} from "src/factory/CREATE3Factory.sol";

contract MultiChainDeployerTest is CrossChainBaseTest {
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

        vm.expectRevert(ImmutableMultiChainDeployer.InvalidSalt.selector);
        address(
            arbitrumDeployer.deployL2YnOFTAdapter(
                keccak256(abi.encode("test")),
                keccak256(abi.encode("proxySalt")),
                address(arbitrumERC20),
                address(arbitrumLzEndpoint),
                _owner,
                _controller,
                l2YnOFTAdapterByteCode
            )
        );
    }

    function test_Deploy_AlreadyDeployed_Revert() public {
        vm.selectFork(arbitrumFork);

        bytes32 arbitrumOFTAdapterSalt = createSalt(_deployer, "OFTAdapter");
        bytes32 arbitrumOFTAdapterProxySalt = createSalt(_deployer, "OFTAdapterProxy");

        vm.expectRevert(ImmutableMultiChainDeployer.AlreadyDeployed.selector);
        vm.prank(_deployer);

        arbitrumDeployer.deployL2YnOFTAdapter(
            arbitrumOFTAdapterSalt,
            arbitrumOFTAdapterProxySalt,
            address(arbitrumERC20),
            address(arbitrumLzEndpoint),
            _owner,
            _controller,
            l2YnOFTAdapterByteCode
        );
    }
}
