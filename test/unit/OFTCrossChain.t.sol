/* solhint-disable check-send-result */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrossChainBaseTest} from "./CrossChainBaseTest.t.sol";

import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import {MessagingFee} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";

import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

contract OFTCrossChainTest is CrossChainBaseTest {
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

    function test_create3() public view {
        assertEq(address(optimismOFTAdapter), address(mainnetOFTAdapter), "All three adapters should be the same");
        assertEq(address(optimismOFTAdapter), address(arbitrumOFTAdapter), "All three adapters should be the same");
        assertEq(address(optimismERC20), address(arbitrumERC20), "ERC20s on L2 should be the same");
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

        // TODO: test verifyPackets across multiple forks
        // BUT LayerZero themselves don't have a way to verify packets across multiple forks
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

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
