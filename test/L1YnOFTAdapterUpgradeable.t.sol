// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrossChainBaseTest} from "./CrossChainBaseTest.t.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import {IMintableBurnableERC20} from "@interfaces/IMintableBurnableERC20.sol";
import {L1YnOFTAdapterUpgradeable} from "@adapters/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@adapters/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@adapters/L2YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

contract Test_L1YnOFTAdapterUpgradeable is CrossChainBaseTest {
    // function test_contructor() public {
    //     vm.selectFork(mainnetFork);
    //     assertEq(aOFT.owner(), address(this));
    //     assertEq(bOFT.owner(), address(this));
    //     assertEq(cOFTAdapter.owner(), address(this));
    //
    //     assertEq(aOFT.balanceOf(userA), initialBalance);
    //     assertEq(bOFT.balanceOf(userB), initialBalance);
    //     assertEq(IERC20(cOFTAdapter.token()).balanceOf(userC), initialBalance);
    //
    //     assertEq(aOFT.token(), address(aOFT));
    //     assertEq(bOFT.token(), address(bOFT));
    //     assertEq(cOFTAdapter.token(), address(cERC20Mock));
    // }

    function test_L1OFTAdapterDeployment() public {}

    //     function test_send_oft() public {
    //     uint256 tokensToSend = 1 ether;
    //     bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
    //     SendParam memory sendParam = SendParam(
    //         bEid,
    //         addressToBytes32(userB),
    //         tokensToSend,
    //         tokensToSend,
    //         options,
    //         "",
    //         ""
    //     );
    //     MessagingFee memory fee = aOFT.quoteSend(sendParam, false);
    //
    //     assertEq(aOFT.balanceOf(userA), initialBalance);
    //     assertEq(bOFT.balanceOf(userB), initialBalance);
    //
    //     vm.prank(userA);
    //     aOFT.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
    //     verifyPackets(bEid, addressToBytes32(address(bOFT)));
    //
    //     assertEq(aOFT.balanceOf(userA), initialBalance - tokensToSend);
    //     assertEq(bOFT.balanceOf(userB), initialBalance + tokensToSend);
    // }
}
