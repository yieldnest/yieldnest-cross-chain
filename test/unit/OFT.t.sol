/* solhint-disable check-send-result, multiple-sends, not-rely-on-time */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {OFTComposerMock} from "test/mocks/OFTComposerMock.sol";

import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

import {IOFT, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {L1OFTAdapterMock} from "test/mocks/L1OFTAdapterMock.sol";
import {L2OFTAdapterMock} from "test/mocks/L2OFTAdapterMock.sol";

import {L2YnERC20Upgradeable as L2YnERC20} from "src/L2YnERC20Upgradeable.sol";

import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

contract OFTTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 public aEid = 1;
    uint32 public bEid = 2;
    uint32 public cEid = 3;

    L1OFTAdapterMock public aOFTAdapter;
    ERC20Mock public aERC20;
    L2OFTAdapterMock public bOFTAdapter;
    L2YnERC20 public bERC20;
    L2OFTAdapterMock public cOFTAdapter;
    L2YnERC20 public cERC20;

    address public userA = address(0x1);
    address public userB = address(0x2);
    address public userC = address(0x3);
    uint256 public initialBalance = 100 ether;

    address public proxyAdmin = makeAddr("proxyAdmin");

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
                    abi.encodeWithSelector(L1OFTAdapterMock.initialize.selector, address(this))
                )
            );
            aOFTAdapter.setRateLimits(_rateLimitConfigs);
        }

        {
            bERC20 = L2YnERC20(
                _deployContractAndProxy(
                    type(L2YnERC20).creationCode,
                    "",
                    abi.encodeWithSelector(L2YnERC20.initialize.selector, "bToken", "bToken", 18, address(this))
                )
            );
            bOFTAdapter = L2OFTAdapterMock(
                _deployContractAndProxy(
                    type(L2OFTAdapterMock).creationCode,
                    abi.encode(address(bERC20), address(endpoints[bEid])),
                    abi.encodeWithSelector(L2OFTAdapterMock.initialize.selector, address(this))
                )
            );
            bERC20.grantRole(bERC20.MINTER_ROLE(), address(bOFTAdapter));
            bOFTAdapter.setRateLimits(_rateLimitConfigs);
        }

        {
            cERC20 = L2YnERC20(
                _deployContractAndProxy(
                    type(L2YnERC20).creationCode,
                    "",
                    abi.encodeWithSelector(L2YnERC20.initialize.selector, "cToken", "cToken", 18, address(this))
                )
            );
            cOFTAdapter = L2OFTAdapterMock(
                _deployContractAndProxy(
                    type(L2OFTAdapterMock).creationCode,
                    abi.encode(address(cERC20), address(endpoints[cEid])),
                    abi.encodeWithSelector(L2OFTAdapterMock.initialize.selector, address(this))
                )
            );
            cERC20.grantRole(cERC20.MINTER_ROLE(), address(cOFTAdapter));
            cOFTAdapter.setRateLimits(_rateLimitConfigs);
        }

        // config and wire the ofts
        address[] memory ofts = new address[](3);
        ofts[0] = address(aOFTAdapter);
        ofts[1] = address(bOFTAdapter);
        ofts[2] = address(cOFTAdapter);
        this.wireOApps(ofts);

        // mint tokens
        aERC20.mint(userA, initialBalance);
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

    function test_erc20Decimals() public {
        assertEq(aERC20.decimals(), 18);
        assertEq(bERC20.decimals(), 18);
        assertEq(cERC20.decimals(), 18);

        L2YnERC20 newYnERC20 = L2YnERC20(
            _deployContractAndProxy(
                type(L2YnERC20).creationCode,
                "",
                abi.encodeWithSelector(L2YnERC20.initialize.selector, "newToken", "newToken", 12, address(this))
            )
        );

        assertEq(newYnERC20.decimals(), 12);
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
        sendParam =
            SendParam(bEid, addressToBytes32(userB), secondTokensToSend, secondTokensToSend, options, "", "");
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
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(170000, 0);
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
        // bERC20.approve(address(bOFTAdapter), tokensToSend);
        bOFTAdapter.send{value: receiveFee.nativeFee}(receiveParam, receiveFee, payable(address(this)));
        vm.stopPrank();
        verifyPackets(aEid, addressToBytes32(address(aOFTAdapter)));

        assertEq(bERC20.balanceOf(userB), 0);
        assertEq(aERC20.balanceOf(userA), initialBalance);
    }

    function test_send_oft_compose_msg() public {
        uint256 tokensToSend = 1 ether;

        OFTComposerMock composer = new OFTComposerMock();

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0)
            .addExecutorLzComposeOption(0, 500000, 0);
        bytes memory composeMsg = hex"1234";
        SendParam memory sendParam = SendParam(
            bEid, addressToBytes32(address(composer)), tokensToSend, tokensToSend, options, composeMsg, ""
        );
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
            msgReceipt.nonce,
            aEid,
            oftReceipt.amountReceivedLD,
            abi.encodePacked(addressToBytes32(userA), composeMsg)
        );
        this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);

        assertEq(aERC20.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(bERC20.balanceOf(address(composer)), tokensToSend);

        assertEq(composer.from(), from_);
        assertEq(composer.guid(), guid_);
        assertEq(composer.message(), composerMsg_);
        assertEq(composer.executor(), address(this));
        assertEq(composer.extraData(), composerMsg_); // default to setting the extraData to the
            // message as well to test
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
        aOFTAdapter.debit(userA, amountToSendLD, minAmountToCreditLD, dstEid);
    }

    function test_debit_slippage_minAmountToCreditLD() public {
        uint256 amountToSendLD = 1 ether;
        uint256 minAmountToCreditLD = 1.00000001 ether;
        uint32 dstEid = aEid;

        vm.expectRevert(
            abi.encodeWithSelector(IOFT.SlippageExceeded.selector, amountToSendLD, minAmountToCreditLD)
        );
        aOFTAdapter.debit(userA, amountToSendLD, minAmountToCreditLD, dstEid);
    }

    function test_L1OFTAdapter_debit() public {
        uint256 amountToSendLD = 1 ether;
        uint256 minAmountToCreditLD = 1 ether;
        uint32 dstEid = aEid;

        aERC20.mint(userC, initialBalance);

        assertEq(aERC20.balanceOf(userC), initialBalance, "incorrect user initial balance");
        assertEq(aERC20.balanceOf(address(this)), 0, "incorrect contract initial balance");
        assertEq(aERC20.balanceOf(address(aOFTAdapter)), 0, "incorrect adapter initial balance");

        vm.expectRevert(
            abi.encodeWithSelector(IOFT.SlippageExceeded.selector, amountToSendLD, minAmountToCreditLD + 1)
        );
        aOFTAdapter.debitView(amountToSendLD, minAmountToCreditLD + 1, dstEid);

        vm.startPrank(userC);
        aERC20.approve(address(aOFTAdapter), amountToSendLD);
        (uint256 amountDebitedLD, uint256 amountToCreditLD) =
            aOFTAdapter.debit(userC, amountToSendLD, minAmountToCreditLD, dstEid);
        vm.stopPrank();

        assertEq(amountDebitedLD, amountToSendLD);
        assertEq(amountToCreditLD, amountToSendLD);

        assertEq(aERC20.balanceOf(userC), initialBalance - amountToSendLD, "incorrect user final balance");
        assertEq(aERC20.balanceOf(address(this)), 0, "incorrect contract final balance");
        // aOFT adapter should have 0 balance because it burns the incoming erc20
        assertEq(aERC20.balanceOf(address(aOFTAdapter)), amountToSendLD, "incorrect adapter final balance");
    }

    function test_L1OFTAdapter_credit() public {
        uint256 amountToCreditLD = 1 ether;
        uint32 srcEid = cEid;

        aERC20.mint(userB, initialBalance);
        aERC20.mint(userC, initialBalance);

        assertEq(aERC20.balanceOf(userB), initialBalance, "incorrect userB initial balance");
        assertEq(aERC20.balanceOf(userC), initialBalance, "incorrect userC initial balance");
        assertEq(aERC20.balanceOf(address(this)), 0, "incorrect contract initial balance");
        assertEq(aERC20.balanceOf(address(aOFTAdapter)), 0, "incorrect adapter initial balance");

        vm.prank(userC);
        aERC20.transfer(address(aOFTAdapter), amountToCreditLD);

        uint256 amountReceived = aOFTAdapter.credit(userB, amountToCreditLD, srcEid);

        assertEq(
            aERC20.balanceOf(address(userB)), initialBalance + amountReceived, "incorrect userB final balance"
        );
        assertEq(
            aERC20.balanceOf(address(userC)), initialBalance - amountReceived, "incorrect userC final balance"
        );
        assertEq(aERC20.balanceOf(address(this)), 0, "incorrect contract final balance");
        assertEq(aERC20.balanceOf(address(aOFTAdapter)), 0, "incorrect adapter final balance");
    }

    function test_L2OFTAdapter_debit() public {
        uint256 amountToSendLD = 1 ether;
        uint256 minAmountToCreditLD = 1 ether;
        uint32 dstEid = cEid;

        cERC20.grantRole(cERC20.MINTER_ROLE(), address(this));
        cERC20.mint(userC, initialBalance);

        assertEq(cERC20.balanceOf(userC), initialBalance, "incorrect user initial balance");
        assertEq(cERC20.balanceOf(address(this)), 0, "incorrect contract initial balance");
        assertEq(cERC20.balanceOf(address(cOFTAdapter)), 0, "incorrect adapter initial balance");

        vm.expectRevert(
            abi.encodeWithSelector(IOFT.SlippageExceeded.selector, amountToSendLD, minAmountToCreditLD + 1)
        );
        cOFTAdapter.debitView(amountToSendLD, minAmountToCreditLD + 1, dstEid);

        vm.startPrank(userC);
        // cERC20.approve(address(cOFTAdapter), amountToSendLD);
        (uint256 amountDebitedLD, uint256 amountToCreditLD) =
            cOFTAdapter.debit(userC, amountToSendLD, minAmountToCreditLD, dstEid);
        vm.stopPrank();

        assertEq(amountDebitedLD, amountToSendLD);
        assertEq(amountToCreditLD, amountToSendLD);

        assertEq(cERC20.balanceOf(userC), initialBalance - amountToSendLD, "incorrect user final balance");
        assertEq(cERC20.balanceOf(address(this)), 0, "incorrect contract final balance");
        // cOFT adapter should have 0 balance because it burns the incoming erc20
        assertEq(cERC20.balanceOf(address(cOFTAdapter)), 0, "incorrect adapter final balance");
    }

    function test_L2OFTAdapter_credit() public {
        uint256 amountToCreditLD = 1 ether;
        uint32 srcEid = cEid;

        assertEq(cERC20.balanceOf(userB), 0, "incorrect userB initial balance");
        assertEq(cERC20.balanceOf(address(this)), 0, "incorrect contract initial balance");
        assertEq(cERC20.balanceOf(address(cOFTAdapter)), 0, "incorrect adapter initial balance");

        uint256 amountReceived = cOFTAdapter.credit(userB, amountToCreditLD, srcEid);

        assertEq(cERC20.balanceOf(address(userB)), amountReceived, "incorrect userB final balance");
        assertEq(cERC20.balanceOf(address(this)), 0, "incorrect contract final balance");
        assertEq(cERC20.balanceOf(address(cOFTAdapter)), 0, "incorrect adapter final balance");
    }

    function _deployContractAndProxy(
        bytes memory _oappBytecode,
        bytes memory _constructorArgs,
        bytes memory _initializeArgs
    )
        internal
        returns (address addr)
    {
        bytes memory bytecode = bytes.concat(abi.encodePacked(_oappBytecode), _constructorArgs);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
            if iszero(extcodesize(addr)) { revert(0, 0) }
        }

        return address(new TransparentUpgradeableProxy(addr, proxyAdmin, _initializeArgs));
    }
}
