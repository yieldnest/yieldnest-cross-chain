/* solhint-disable gas-custom-errors, check-send-result */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {L1OFTAdapterMock} from "test/mocks/L1OFTAdapterMock.sol";
import {L2OFTAdapterMock} from "test/mocks/L2OFTAdapterMock.sol";

import {Test} from "forge-std/Test.sol";
import {BaseData} from "script/BaseData.s.sol";

interface IMockOFTAdapter {
    function mock() external returns (uint256);
}

contract TestUpgrades is Test, BaseData {
    address public oftAdapter;
    address public timelock;
    address public proxyAdmin;
    address public erc20;
    Data public data;
    bool public isL1;

    function setUp() public virtual override {
        super.setUp();

        // Source chain ID
        // If we're on Fraxtal testnet (2522), Morph testnet (2810), or Holesky (17000),
        // use Holesky (17000) as the source chain since it's the L1 testnet.
        // Otherwise default to Ethereum mainnet (1)
        uint256 sourceChainId = block.chainid;
        uint256 baseChainId = sourceChainId == 2522 || sourceChainId == 2810 || sourceChainId == 17000 ? 17000 : 1;
        isL1 = baseChainId == sourceChainId;

        data = getData(block.chainid);

        // Load deployment config
        string memory json =
            vm.readFile(string.concat("deployments/ynETHx-", vm.toString(baseChainId), "-v0.0.1.json"));

        erc20 = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".erc20Address")), (address)
        );

        oftAdapter = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapter")), (address)
        );

        timelock = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapterTimelock")),
            (address)
        );

        proxyAdmin = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".oftAdapterProxyAdmin")),
            (address)
        );
    }

    function testUpgradeOFTAdapter() external {
        vm.expectRevert();
        IMockOFTAdapter(oftAdapter).mock();

        address implementation = isL1
            ? address(new L1OFTAdapterMock(erc20, data.LZ_ENDPOINT))
            : address(new L2OFTAdapterMock(erc20, data.LZ_ENDPOINT));

        TimelockController timelock_ = TimelockController(payable(timelock));

        // schedule a proxy upgrade transaction on the timelock
        // the traget is the proxy admin for the max Vault Proxy Contract
        address target = proxyAdmin;
        uint256 value = 0;

        bytes4 selector = bytes4(keccak256("upgradeAndCall(address,address,bytes)"));

        bytes memory initData = abi.encodeWithSelector(
            isL1 ? L1OFTAdapterMock.reinitialize.selector : L2OFTAdapterMock.reinitialize.selector
        );
        bytes memory upgradeData = abi.encodeWithSelector(selector, oftAdapter, address(implementation), initData);

        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("chad");

        uint256 delay = 86400;

        vm.startPrank(data.PROXY_ADMIN);
        timelock_.schedule(target, value, upgradeData, predecessor, salt, delay);
        vm.stopPrank();

        bytes32 id = keccak256(abi.encode(target, value, upgradeData, predecessor, salt));
        assert(timelock_.getOperationState(id) == TimelockController.OperationState.Waiting);

        assertEq(timelock_.isOperationReady(id), false);
        assertEq(timelock_.isOperationDone(id), false);
        assertEq(timelock_.isOperation(id), true);

        //execute the transaction
        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + 86401);
        vm.startPrank(data.PROXY_ADMIN);
        timelock_.execute(target, value, upgradeData, predecessor, salt);
        vm.stopPrank();

        // Verify the transaction was executed successfully
        assertEq(timelock_.isOperationReady(id), false);
        assertEq(timelock_.isOperationDone(id), true);
        assert(timelock_.getOperationState(id) == TimelockController.OperationState.Done);

        assertEq(IMockOFTAdapter(oftAdapter).mock(), 1);
    }
}
