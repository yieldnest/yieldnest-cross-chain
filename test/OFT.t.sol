// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oapp/libs/OptionsBuilder.sol";

import {OFTUpgradeableMock} from "@layerzerolabs/lz-evm-oapp-v2/test/mocks/OFTUpgradeableMock.sol";
import {
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/OFTCoreUpgradeable.sol";
import {OFTAdapterUpgradeableMock} from "@layerzerolabs/lz-evm-oapp-v2/test/mocks/OFTAdapterUpgradeableMock.sol";
import {ERC20Mock} from "@layerzerolabs/lz-evm-oapp-v2/test/mocks/ERC20Mock.sol";
import {OFTComposerMock} from "@layerzerolabs/lz-evm-oapp-v2/test/mocks/OFTComposerMock.sol";
import {OFTInspectorMock, IOAppMsgInspector} from "@layerzerolabs/lz-evm-oapp-v2/test/mocks/OFTInspectorMock.sol";
import {
    IOAppOptionsType3,
    EnforcedOptionParam
} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oapp/libs/OAppOptionsType3Upgradeable.sol";

import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/libs/OFTMsgCodec.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/libs/OFTComposeMsgCodec.sol";

import {
    IOFT, SendParam, OFTReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/interfaces/IOFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "forge-std/console.sol";
import {TestHelper, Initializable} from "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";
import {L1OFTAdapterMock} from "./mocks/L1OFTAdapterMock.sol";
import {L2OFTAdapterMock} from "./mocks/L2OFTAdapterMock.sol";

import {L2YnERC20Upgradeable as L2YnERC20} from "@adapters/L2YnERC20Upgradeable.sol";

import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

contract OFTTest is TestHelper {
    using OptionsBuilder for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;
    uint32 cEid = 3;

    L1OFTAdapterMock aOFTAdapter;
    ERC20Mock aERC20;
    L2OFTAdapterMock bOFTAdapter;
    L2YnERC20 bERC20;
    L2OFTAdapterMock cOFTAdapter;
    L2YnERC20 cERC20;

    OFTInspectorMock oAppInspector;

    address public userA = address(0x1);
    address public userB = address(0x2);
    address public userC = address(0x3);
    uint256 public initialBalance = 100 ether;

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
        vm.deal(userC, 1000 ether);

        super.setUp();
        setUpEndpoints(3, LibraryType.UltraLightNode);
        RateLimiter.RateLimitConfig[] memory _rateLimitConfigs = new RateLimiter.RateLimitConfig[](3);
        _rateLimitConfigs[0] = RateLimiter.RateLimitConfig({dstEid: 1, limit: 10 ether, window: 1 days});
        _rateLimitConfigs[1] = RateLimiter.RateLimitConfig({dstEid: 2, limit: 10 ether, window: 1 days});
        _rateLimitConfigs[2] = RateLimiter.RateLimitConfig({dstEid: 3, limit: 10 ether, window: 1 days});

        {
            aERC20 = new ERC20Mock("aToken", "aToken");
            aOFTAdapter = L1OFTAdapterMock(
                _deployContractAndProxy(
                    type(L1OFTAdapterMock).creationCode,
                    abi.encode(address(aERC20), address(endpoints[aEid])),
                    abi.encodeWithSelector(L1OFTAdapterMock.initialize.selector, address(this), _rateLimitConfigs)
                )
            );
        }

        {
            bERC20 = L2YnERC20(
                _deployContractAndProxy(
                    type(L2YnERC20).creationCode,
                    "",
                    abi.encodeWithSelector(L2YnERC20.initialize.selector, "bToken", "bToken", address(this))
                )
            );
            bOFTAdapter = L2OFTAdapterMock(
                _deployContractAndProxy(
                    type(L2OFTAdapterMock).creationCode,
                    abi.encode(address(bERC20), address(endpoints[bEid])),
                    abi.encodeWithSelector(L2OFTAdapterMock.initialize.selector, address(this), _rateLimitConfigs)
                )
            );
            bERC20.grantRole(bERC20.MINTER_ROLE(), address(bOFTAdapter));
        }

        {
            cERC20 = L2YnERC20(
                _deployContractAndProxy(
                    type(L2YnERC20).creationCode,
                    "",
                    abi.encodeWithSelector(L2YnERC20.initialize.selector, "cToken", "cToken", address(this))
                )
            );
            cOFTAdapter = L2OFTAdapterMock(
                _deployContractAndProxy(
                    type(L2OFTAdapterMock).creationCode,
                    abi.encode(address(cERC20), address(endpoints[cEid])),
                    abi.encodeWithSelector(L2OFTAdapterMock.initialize.selector, address(this), _rateLimitConfigs)
                )
            );
            cERC20.grantRole(cERC20.MINTER_ROLE(), address(cOFTAdapter));
        }

        // config and wire the ofts
        address[] memory ofts = new address[](3);
        ofts[0] = address(aOFTAdapter);
        ofts[1] = address(bOFTAdapter);
        ofts[2] = address(cOFTAdapter);
        this.wireOApps(ofts);

        // mint tokens
        aERC20.mint(userA, initialBalance);
        // bOFT.mint(userB, initialBalance);
        // cERC20Mock.mint(userC, initialBalance);

        // deploy a universal inspector, can be used by each oft
        oAppInspector = new OFTInspectorMock();
    }

    function test_constructor() public view {
        assertEq(aOFTAdapter.owner(), address(this));
        assertEq(bOFTAdapter.owner(), address(this));
        assertEq(cOFTAdapter.owner(), address(this));

        assertEq(aERC20.balanceOf(userA), initialBalance);
        // assertEq(bOFT.balanceOf(userB), initialBalance);
        // assertEq(IERC20(cOFTAdapter.token()).balanceOf(userC), initialBalance);

        assertEq(aOFTAdapter.token(), address(aERC20));
        assertEq(bOFTAdapter.token(), address(bERC20));
        assertEq(cOFTAdapter.token(), address(cERC20));
    }

    function test_oftVersion() public view {
        (bytes4 interfaceId,) = aOFTAdapter.oftVersion();
        bytes4 expectedId = 0x02e49c2c;
        assertEq(interfaceId, expectedId);
    }

    function test_send_oft() public {
        uint256 tokensToSend = 1 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam =
            SendParam(bEid, addressToBytes32(userB), tokensToSend, tokensToSend, options, "", "");
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        assertEq(aERC20.balanceOf(userA), initialBalance);
        assertEq(bERC20.balanceOf(userB), 0);

        vm.startPrank(userA);
        aERC20.approve(address(aOFTAdapter), tokensToSend);
        aOFTAdapter.send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));
        vm.stopPrank();
        verifyPackets(bEid, addressToBytes32(address(bOFTAdapter)));

        assertEq(aERC20.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(aERC20.balanceOf(address(aOFTAdapter)), tokensToSend);
        assertEq(bERC20.balanceOf(userB), 0 + tokensToSend);
    }

    function test_send_oft_rate_limited() public {
        uint256 tokensToSend = 20 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam =
            SendParam(bEid, addressToBytes32(userB), tokensToSend, tokensToSend, options, "", "");
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        assertEq(aERC20.balanceOf(userA), initialBalance);
        assertEq(bERC20.balanceOf(userB), 0);

        vm.startPrank(userA);
        aERC20.approve(address(aOFTAdapter), tokensToSend);
        vm.expectRevert(RateLimiter.RateLimitExceeded.selector);
        aOFTAdapter.send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));
        vm.stopPrank();
    }

    function test_send_oft_rate_limits_lifted() public {
        uint256 firstTokensToSend = 9 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam =
            SendParam(bEid, addressToBytes32(userB), firstTokensToSend, firstTokensToSend, options, "", "");
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        assertEq(aERC20.balanceOf(userA), initialBalance);
        assertEq(bERC20.balanceOf(userB), 0);

        vm.startPrank(userA);
        aERC20.approve(address(aOFTAdapter), firstTokensToSend);
        aOFTAdapter.send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));
        vm.stopPrank();

        verifyPackets(bEid, addressToBytes32(address(bOFTAdapter)));

        assertEq(aERC20.balanceOf(userA), initialBalance - firstTokensToSend);
        assertEq(aERC20.balanceOf(address(aOFTAdapter)), firstTokensToSend);
        assertEq(bERC20.balanceOf(userB), 0 + firstTokensToSend);

        uint256 secondTokensToSend = 5 ether;
        sendParam = SendParam(bEid, addressToBytes32(userB), secondTokensToSend, secondTokensToSend, options, "", "");
        fee = aOFTAdapter.quoteSend(sendParam, false);

        vm.startPrank(userA);
        aERC20.approve(address(aOFTAdapter), secondTokensToSend);
        vm.expectRevert(RateLimiter.RateLimitExceeded.selector);
        aOFTAdapter.send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));
        vm.stopPrank();

        //pass the time
        vm.warp(block.timestamp + 1 days);

        vm.prank(userA);
        aOFTAdapter.send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));

        verifyPackets(bEid, addressToBytes32(address(bOFTAdapter)));

        assertEq(aERC20.balanceOf(userA), initialBalance - firstTokensToSend - secondTokensToSend);
        assertEq(aERC20.balanceOf(address(aOFTAdapter)), firstTokensToSend + secondTokensToSend);
        assertEq(bERC20.balanceOf(userB), 0 + firstTokensToSend + secondTokensToSend);
    }

    function test_send_oft_and_receive() public {
        uint256 tokensToSend = 1 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam =
            SendParam(bEid, addressToBytes32(userB), tokensToSend, tokensToSend, options, "", "");
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        assertEq(aERC20.balanceOf(userA), initialBalance);
        assertEq(bERC20.balanceOf(userB), 0);

        vm.startPrank(userA);
        aERC20.approve(address(aOFTAdapter), tokensToSend);
        aOFTAdapter.send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));
        vm.stopPrank();
        verifyPackets(bEid, addressToBytes32(address(bOFTAdapter)));

        assertEq(aERC20.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(aERC20.balanceOf(address(aOFTAdapter)), tokensToSend);
        assertEq(bERC20.balanceOf(userB), 0 + tokensToSend);

        SendParam memory receiveParam =
            SendParam(aEid, addressToBytes32(userA), tokensToSend, tokensToSend, options, "", "");

        MessagingFee memory receiveFee = bOFTAdapter.quoteSend(receiveParam, false);

        assertEq(bERC20.balanceOf(userB), tokensToSend);
        assertEq(aERC20.balanceOf(userA), initialBalance - tokensToSend);

        vm.startPrank(userB);
        bERC20.approve(address(bOFTAdapter), tokensToSend);
        bOFTAdapter.send{value: receiveFee.nativeFee}(receiveParam, receiveFee, payable(address(this)));
        vm.stopPrank();
        verifyPackets(aEid, addressToBytes32(address(aOFTAdapter)));

        assertEq(bERC20.balanceOf(userB), 0);
        assertEq(aERC20.balanceOf(userA), initialBalance);
    }

    function test_send_oft_compose_msg() public {
        uint256 tokensToSend = 1 ether;

        OFTComposerMock composer = new OFTComposerMock();

        bytes memory options =
            OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0).addExecutorLzComposeOption(0, 500000, 0);
        bytes memory composeMsg = hex"1234";
        SendParam memory sendParam =
            SendParam(bEid, addressToBytes32(address(composer)), tokensToSend, tokensToSend, options, composeMsg, "");
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        assertEq(aERC20.balanceOf(userA), initialBalance);
        assertEq(bERC20.balanceOf(address(composer)), 0);

        vm.startPrank(userA);
        aERC20.approve(address(aOFTAdapter), tokensToSend);
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) =
            aOFTAdapter.send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));
        vm.stopPrank();
        verifyPackets(bEid, addressToBytes32(address(bOFTAdapter)));

        // lzCompose params
        uint32 dstEid_ = bEid;
        address from_ = address(bOFTAdapter);
        bytes memory options_ = options;
        bytes32 guid_ = msgReceipt.guid;
        address to_ = address(composer);
        bytes memory composerMsg_ = OFTComposeMsgCodec.encode(
            msgReceipt.nonce, aEid, oftReceipt.amountReceivedLD, abi.encodePacked(addressToBytes32(userA), composeMsg)
        );
        this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);

        assertEq(aERC20.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(bERC20.balanceOf(address(composer)), tokensToSend);

        assertEq(composer.from(), from_);
        assertEq(composer.guid(), guid_);
        assertEq(composer.message(), composerMsg_);
        assertEq(composer.executor(), address(this));
        assertEq(composer.extraData(), composerMsg_); // default to setting the extraData to the message as well to test
    }

    function test_oft_compose_codec() public view {
        uint64 nonce = 1;
        uint32 srcEid = 2;
        uint256 amountCreditLD = 3;
        bytes memory composeMsg = hex"1234";

        bytes memory message = OFTComposeMsgCodec.encode(
            nonce, srcEid, amountCreditLD, abi.encodePacked(addressToBytes32(msg.sender), composeMsg)
        );
        (uint64 nonce_, uint32 srcEid_, uint256 amountCreditLD_, bytes32 composeFrom_, bytes memory composeMsg_) =
            this.decodeOFTComposeMsgCodec(message);

        assertEq(nonce_, nonce);
        assertEq(srcEid_, srcEid);
        assertEq(amountCreditLD_, amountCreditLD);
        assertEq(composeFrom_, addressToBytes32(msg.sender));
        assertEq(composeMsg_, composeMsg);
    }

    function decodeOFTComposeMsgCodec(bytes calldata message)
        public
        pure
        returns (uint64 nonce, uint32 srcEid, uint256 amountCreditLD, bytes32 composeFrom, bytes memory composeMsg)
    {
        nonce = OFTComposeMsgCodec.nonce(message);
        srcEid = OFTComposeMsgCodec.srcEid(message);
        amountCreditLD = OFTComposeMsgCodec.amountLD(message);
        composeFrom = OFTComposeMsgCodec.composeFrom(message);
        composeMsg = OFTComposeMsgCodec.composeMsg(message);
    }

    function test_debit_slippage_removeDust() public {
        uint256 amountToSendLD = 1.23456789 ether;
        uint256 minAmountToCreditLD = 1.23456789 ether;
        uint32 dstEid = aEid;

        // remove the dust form the shared decimal conversion
        assertEq(aOFTAdapter.removeDust(amountToSendLD), 1.234567 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                IOFT.SlippageExceeded.selector, aOFTAdapter.removeDust(amountToSendLD), minAmountToCreditLD
            )
        );
        aOFTAdapter.debit(amountToSendLD, minAmountToCreditLD, dstEid);
    }

    /*
    function test_debit_slippage_minAmountToCreditLD() public {
        uint256 amountToSendLD = 1 ether;
        uint256 minAmountToCreditLD = 1.00000001 ether;
        uint32 dstEid = aEid;

        vm.expectRevert(abi.encodeWithSelector(IOFT.SlippageExceeded.selector, amountToSendLD, minAmountToCreditLD));
        aOFT.debit(amountToSendLD, minAmountToCreditLD, dstEid);
    }

    function test_toLD() public {
        uint64 amountSD = 1000;
        assertEq(amountSD * aOFT.decimalConversionRate(), aOFT.toLD(uint64(amountSD)));
    }

    function test_toSD() public {
        uint256 amountLD = 1000000;
        assertEq(amountLD / aOFT.decimalConversionRate(), aOFT.toSD(amountLD));
    }

    function test_oft_debit() public {
        uint256 amountToSendLD = 1 ether;
        uint256 minAmountToCreditLD = 1 ether;
        uint32 dstEid = aEid;

        assertEq(aOFT.balanceOf(userA), initialBalance);
        assertEq(aOFT.balanceOf(address(this)), 0);

        vm.prank(userA);
        (uint256 amountDebitedLD, uint256 amountToCreditLD) = aOFT.debit(amountToSendLD, minAmountToCreditLD, dstEid);

        assertEq(amountDebitedLD, amountToSendLD);
        assertEq(amountToCreditLD, amountToSendLD);

        assertEq(aOFT.balanceOf(userA), initialBalance - amountToSendLD);
        assertEq(aOFT.balanceOf(address(this)), 0);
    }

    function test_oft_credit() public {
        uint256 amountToCreditLD = 1 ether;
        uint32 srcEid = aEid;

        assertEq(aOFT.balanceOf(userA), initialBalance);
        assertEq(aOFT.balanceOf(address(this)), 0);

        vm.prank(userA);
        uint256 amountReceived = aOFT.credit(userA, amountToCreditLD, srcEid);

        assertEq(aOFT.balanceOf(userA), initialBalance + amountReceived);
        assertEq(aOFT.balanceOf(address(this)), 0);
    }

    function test_oft_adapter_debit() public {
        uint256 amountToSendLD = 1 ether;
        uint256 minAmountToCreditLD = 1 ether;
        uint32 dstEid = cEid;

        assertEq(cERC20Mock.balanceOf(userC), initialBalance);
        assertEq(cERC20Mock.balanceOf(address(cOFTAdapter)), 0);

        vm.prank(userC);
        vm.expectRevert(
            abi.encodeWithSelector(IOFT.SlippageExceeded.selector, amountToSendLD, minAmountToCreditLD + 1)
        );
        cOFTAdapter.debitView(amountToSendLD, minAmountToCreditLD + 1, dstEid);

        vm.prank(userC);
        cERC20Mock.approve(address(cOFTAdapter), amountToSendLD);
        vm.prank(userC);
        (uint256 amountDebitedLD, uint256 amountToCreditLD) = cOFTAdapter.debit(
            amountToSendLD,
            minAmountToCreditLD,
            dstEid
        );

        assertEq(amountDebitedLD, amountToSendLD);
        assertEq(amountToCreditLD, amountToSendLD);

        assertEq(cERC20Mock.balanceOf(userC), initialBalance - amountToSendLD);
        assertEq(cERC20Mock.balanceOf(address(cOFTAdapter)), amountToSendLD);
    }

    function test_oft_adapter_credit() public {
        uint256 amountToCreditLD = 1 ether;
        uint32 srcEid = cEid;

        assertEq(cERC20Mock.balanceOf(userC), initialBalance);
        assertEq(cERC20Mock.balanceOf(address(cOFTAdapter)), 0);

        vm.prank(userC);
        cERC20Mock.transfer(address(cOFTAdapter), amountToCreditLD);

        uint256 amountReceived = cOFTAdapter.credit(userB, amountToCreditLD, srcEid);

        assertEq(cERC20Mock.balanceOf(userC), initialBalance - amountToCreditLD);
        assertEq(cERC20Mock.balanceOf(address(userB)), amountReceived);
        assertEq(cERC20Mock.balanceOf(address(cOFTAdapter)), 0);
    }

    function decodeOFTMsgCodec(
        bytes calldata message
    ) public pure returns (bool isComposed, bytes32 sendTo, uint64 amountSD, bytes memory composeMsg) {
        isComposed = OFTMsgCodec.isComposed(message);
        sendTo = OFTMsgCodec.sendTo(message);
        amountSD = OFTMsgCodec.amountSD(message);
        composeMsg = OFTMsgCodec.composeMsg(message);
    }

    function test_oft_build_msg() public {
        uint32 dstEid = bEid;
        bytes32 to = addressToBytes32(userA);
        uint256 amountToSendLD = 1.23456789 ether;
        uint256 minAmountToCreditLD = aOFT.removeDust(amountToSendLD);

        // params for buildMsgAndOptions
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        bytes memory composeMsg = hex"1234";
        SendParam memory sendParam = SendParam(
            dstEid,
            to,
            amountToSendLD,
            minAmountToCreditLD,
            extraOptions,
            composeMsg,
            ""
        );
        uint256 amountToCreditLD = minAmountToCreditLD;

        (bytes memory message, ) = aOFT.buildMsgAndOptions(sendParam, amountToCreditLD);

        (bool isComposed_, bytes32 sendTo_, uint64 amountSD_, bytes memory composeMsg_) = this.decodeOFTMsgCodec(
            message
        );

        assertEq(isComposed_, true);
        assertEq(sendTo_, to);
        assertEq(amountSD_, aOFT.toSD(amountToCreditLD));
        bytes memory expectedComposeMsg = abi.encodePacked(addressToBytes32(address(this)), composeMsg);
        assertEq(composeMsg_, expectedComposeMsg);
    }

    function test_oft_build_msg_no_compose_msg() public {
        uint32 dstEid = bEid;
        bytes32 to = addressToBytes32(userA);
        uint256 amountToSendLD = 1.23456789 ether;
        uint256 minAmountToCreditLD = aOFT.removeDust(amountToSendLD);

        // params for buildMsgAndOptions
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        bytes memory composeMsg = "";
        SendParam memory sendParam = SendParam(
            dstEid,
            to,
            amountToSendLD,
            minAmountToCreditLD,
            extraOptions,
            composeMsg,
            ""
        );
        uint256 amountToCreditLD = minAmountToCreditLD;

        (bytes memory message, ) = aOFT.buildMsgAndOptions(sendParam, amountToCreditLD);

        (bool isComposed_, bytes32 sendTo_, uint64 amountSD_, bytes memory composeMsg_) = this.decodeOFTMsgCodec(
            message
        );

        assertEq(isComposed_, false);
        assertEq(sendTo_, to);
        assertEq(amountSD_, aOFT.toSD(amountToCreditLD));
        assertEq(composeMsg_, "");
    }

    function test_set_enforced_options() public {
        uint32 eid = 1;

        bytes memory optionsTypeOne = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        bytes memory optionsTypeTwo = OptionsBuilder.newOptions().addExecutorLzReceiveOption(250000, 0);

        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam(eid, 1, optionsTypeOne);
        enforcedOptions[1] = EnforcedOptionParam(eid, 2, optionsTypeTwo);

        aOFT.setEnforcedOptions(enforcedOptions);

        assertEq(aOFT.enforcedOptions(eid, 1), optionsTypeOne);
        assertEq(aOFT.enforcedOptions(eid, 2), optionsTypeTwo);
    }

    function test_assert_options_type3_revert() public {
        uint32 eid = 1;
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](1);

        enforcedOptions[0] = EnforcedOptionParam(eid, 1, hex"0004"); // not type 3
        vm.expectRevert(abi.encodeWithSelector(IOAppOptionsType3.InvalidOptions.selector, hex"0004"));
        aOFT.setEnforcedOptions(enforcedOptions);

        enforcedOptions[0] = EnforcedOptionParam(eid, 1, hex"0002"); // not type 3
        vm.expectRevert(abi.encodeWithSelector(IOAppOptionsType3.InvalidOptions.selector, hex"0002"));
        aOFT.setEnforcedOptions(enforcedOptions);

        enforcedOptions[0] = EnforcedOptionParam(eid, 1, hex"0001"); // not type 3
        vm.expectRevert(abi.encodeWithSelector(IOAppOptionsType3.InvalidOptions.selector, hex"0001"));
        aOFT.setEnforcedOptions(enforcedOptions);

        enforcedOptions[0] = EnforcedOptionParam(eid, 1, hex"0003"); // IS type 3
        aOFT.setEnforcedOptions(enforcedOptions); // doesnt revert cus option type 3
    }

    function test_combine_options() public {
        uint32 eid = 1;
        uint16 msgType = 1;

        bytes memory enforcedOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        EnforcedOptionParam[] memory enforcedOptionsArray = new EnforcedOptionParam[](1);
        enforcedOptionsArray[0] = EnforcedOptionParam(eid, msgType, enforcedOptions);
        aOFT.setEnforcedOptions(enforcedOptionsArray);

        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorNativeDropOption(
            1.2345 ether,
            addressToBytes32(userA)
        );

        bytes memory expectedOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0)
            .addExecutorNativeDropOption(1.2345 ether, addressToBytes32(userA));

        bytes memory combinedOptions = aOFT.combineOptions(eid, msgType, extraOptions);
        assertEq(combinedOptions, expectedOptions);
    }

    function test_combine_options_no_extra_options() public {
        uint32 eid = 1;
        uint16 msgType = 1;

        bytes memory enforcedOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        EnforcedOptionParam[] memory enforcedOptionsArray = new EnforcedOptionParam[](1);
        enforcedOptionsArray[0] = EnforcedOptionParam(eid, msgType, enforcedOptions);
        aOFT.setEnforcedOptions(enforcedOptionsArray);

        bytes memory expectedOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        bytes memory combinedOptions = aOFT.combineOptions(eid, msgType, "");
        assertEq(combinedOptions, expectedOptions);
    }

    function test_combine_options_no_enforced_options() public {
        uint32 eid = 1;
        uint16 msgType = 1;

        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorNativeDropOption(
            1.2345 ether,
            addressToBytes32(userA)
        );

        bytes memory expectedOptions = OptionsBuilder.newOptions().addExecutorNativeDropOption(
            1.2345 ether,
            addressToBytes32(userA)
        );

        bytes memory combinedOptions = aOFT.combineOptions(eid, msgType, extraOptions);
        assertEq(combinedOptions, expectedOptions);
    }

    function test_oapp_inspector_inspect() public {
        uint32 dstEid = bEid;
        bytes32 to = addressToBytes32(userA);
        uint256 amountToSendLD = 1.23456789 ether;
        uint256 minAmountToCreditLD = aOFT.removeDust(amountToSendLD);

        // params for buildMsgAndOptions
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        bytes memory composeMsg = "";
        SendParam memory sendParam = SendParam(
            dstEid,
            to,
            amountToSendLD,
            minAmountToCreditLD,
            extraOptions,
            composeMsg,
            ""
        );
        uint256 amountToCreditLD = minAmountToCreditLD;

        // doesnt revert
        (bytes memory message, ) = aOFT.buildMsgAndOptions(sendParam, amountToCreditLD);

        // deploy a universal inspector, it automatically reverts
        oAppInspector = new OFTInspectorMock();
        // set the inspector
        aOFT.setMsgInspector(address(oAppInspector));

        // does revert because inspector is set
        vm.expectRevert(abi.encodeWithSelector(IOAppMsgInspector.InspectionFailed.selector, message, extraOptions));
        (message, ) = aOFT.buildMsgAndOptions(sendParam, amountToCreditLD);
    }
    */
}
