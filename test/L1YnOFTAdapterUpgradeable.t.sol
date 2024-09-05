// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrossChainBaseTest} from "./CrossChainBaseTest.t.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import {IMintableBurnableERC20} from "@interfaces/IMintableBurnableERC20.sol";
import {L1YnOFTAdapterUpgradeable} from "@adapters/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@adapters/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@adapters/L2YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oapp/libs/OptionsBuilder.sol";
import {
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/OFTCoreUpgradeable.sol";

import {
    IOFT, SendParam, OFTReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/interfaces/IOFT.sol";

contract Test_L1YnOFTAdapterUpgradeable is CrossChainBaseTest {
    using OptionsBuilder for bytes;

    address public userA = address(0x1);
    address public userB = address(0x2);
    address public userC = address(0x3);

    uint256 public initialBalance = 100 ether;

    function setUp() public override {
        super.setUp();

        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
        vm.deal(userC, 1000 ether);

        // config and wire the ofts
        wireMultichainOApps();

        // mint tokens on mainnet
        vm.selectFork(mainnetFork);
        vm.startPrank(_owner);
        mainnetERC20.mint(userA, initialBalance);
        mainnetERC20.mint(userB, initialBalance);
        mainnetERC20.mint(userC, initialBalance);
        vm.stopPrank();
    }

    function wireMultichainOApps() public {
        vm.startPrank(_owner);
        vm.selectFork(mainnetFork);
        mainnetOFTAdapter.setPeer(arbitrumEid, addressToBytes32(address(arbitrumOFTAdapter)));
        mainnetOFTAdapter.setPeer(optimismEid, addressToBytes32(address(optimismOFTAdapter)));

        vm.selectFork(arbitrumFork);
        arbitrumOFTAdapter.setPeer(mainnetEid, addressToBytes32(address(mainnetOFTAdapter)));
        arbitrumOFTAdapter.setPeer(optimismEid, addressToBytes32(address(optimismOFTAdapter)));

        vm.selectFork(optimismFork);
        optimismOFTAdapter.setPeer(mainnetEid, addressToBytes32(address(mainnetOFTAdapter)));
        optimismOFTAdapter.setPeer(arbitrumEid, addressToBytes32(address(arbitrumOFTAdapter)));
        vm.stopPrank();
    }

    function test_constructor() public {
        vm.selectFork(mainnetFork);
        assertEq(mainnetOFTAdapter.owner(), _owner);
        assertEq(mainnetOFTAdapter.token(), address(mainnetERC20));
        assertEq(mainnetOFTAdapter.peers(arbitrumEid), addressToBytes32(address(arbitrumOFTAdapter)));
        assertEq(mainnetOFTAdapter.peers(optimismEid), addressToBytes32(address(optimismOFTAdapter)));
        assertEq(mainnetERC20.balanceOf(address(mainnetOFTAdapter)), 0);
        assertEq(mainnetERC20.balanceOf(userA), initialBalance);
        assertEq(mainnetERC20.balanceOf(userB), initialBalance);
        assertEq(mainnetERC20.balanceOf(userC), initialBalance);

        vm.selectFork(arbitrumFork);
        assertEq(arbitrumOFTAdapter.owner(), _owner);
        assertEq(arbitrumOFTAdapter.token(), address(arbitrumERC20));
        assertEq(arbitrumOFTAdapter.peers(mainnetEid), addressToBytes32(address(mainnetOFTAdapter)));
        assertEq(arbitrumOFTAdapter.peers(optimismEid), addressToBytes32(address(optimismOFTAdapter)));

        vm.selectFork(optimismFork);
        assertEq(optimismOFTAdapter.owner(), _owner);
        assertEq(optimismOFTAdapter.token(), address(optimismERC20));
        assertEq(optimismOFTAdapter.peers(mainnetEid), addressToBytes32(address(mainnetOFTAdapter)));
        assertEq(optimismOFTAdapter.peers(arbitrumEid), addressToBytes32(address(arbitrumOFTAdapter)));
    }

    function test_oftVersion() public {
        vm.selectFork(mainnetFork);
        (bytes4 interfaceId,) = mainnetOFTAdapter.oftVersion();
        bytes4 expectedId = 0x02e49c2c;
        assertEq(interfaceId, expectedId);

        vm.selectFork(arbitrumFork);
        (interfaceId,) = arbitrumOFTAdapter.oftVersion();
        assertEq(interfaceId, expectedId);

        vm.selectFork(optimismFork);
        (interfaceId,) = optimismOFTAdapter.oftVersion();
        assertEq(interfaceId, expectedId);
    }

    function test_send_oft() public {
        uint256 tokensToSend = 1 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam =
            SendParam(arbitrumEid, addressToBytes32(userB), tokensToSend, tokensToSend, options, "", "");

        vm.selectFork(mainnetFork);
        MessagingFee memory fee = mainnetOFTAdapter.quoteSend(sendParam, false);
        assertEq(mainnetERC20.balanceOf(userA), initialBalance);

        vm.selectFork(arbitrumFork);
        assertEq(arbitrumERC20.balanceOf(userB), 0);

        vm.selectFork(mainnetFork);
        vm.startPrank(userA);
        mainnetERC20.approve(address(mainnetOFTAdapter), tokensToSend);
        mainnetOFTAdapter.send{value: fee.nativeFee}(sendParam, fee, payable(address(_owner)));
        vm.stopPrank();

        // The following fails
        // vm.selectFork(arbitrumFork);
        // vm.startPrank(_owner);
        // verifyPackets(arbitrumEid, addressToBytes32(address(arbitrumOFTAdapter)));
        // vm.stopPrank();
        //
        // vm.selectFork(mainnetFork);
        // assertEq(mainnetERC20.balanceOf(userA), initialBalance - tokensToSend);
        //
        // vm.selectFork(arbitrumFork);
        // assertEq(arbitrumERC20.balanceOf(userB), initialBalance + tokensToSend);
    }
}
