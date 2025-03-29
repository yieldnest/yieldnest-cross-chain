/* solhint-disable gas-custom-errors, check-send-result */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {CREATE3Factory} from "src/factory/CREATE3Factory.sol";
import {ImmutableMultiChainDeployer} from "src/factory/ImmutableMultiChainDeployer.sol";
import {L1OFTAdapterMock} from "test/mocks/L1OFTAdapterMock.sol";
import {L2OFTAdapterMock} from "test/mocks/L2OFTAdapterMock.sol";

import {Test} from "forge-std/Test.sol";
import {BaseData} from "script/BaseData.s.sol";

interface IMockOFTAdapter {
    function mock() external returns (uint256);
}

contract TestFactoryDeployment is Test, BaseData {
    ImmutableMultiChainDeployer public immutableMultiChainDeployer;
    Data public data;
    address public deployer;

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
        deployer = data.OFT_OWNER;
        // Load deployment config
        string memory json =
            vm.readFile(string.concat("deployments/ynETHx-", vm.toString(baseChainId), "-v0.0.1.json"));

        address immutableMultiChainDeployerAddress = abi.decode(
            vm.parseJson(json, string.concat(".chains.", vm.toString(sourceChainId), ".multiChainDeployer")),
            (address)
        );

        immutableMultiChainDeployer = ImmutableMultiChainDeployer(immutableMultiChainDeployerAddress);
    }

    function createSalt(address _deployerAddress, string memory _label) internal view returns (bytes32 _salt) {
        require(bytes(baseInput.erc20Symbol).length > 0, "Invalid ERC20 Symbol");

        _salt = bytes32(
            abi.encodePacked(
                bytes20(_deployerAddress),
                bytes12(bytes32(keccak256(abi.encode(_label, baseInput.erc20Symbol, VERSION))))
            )
        );
    }

    function test_Deploy_Create3Factory() public {
        // deploy create3 factory with immutableMultiChainDeployer deploy funciont
        bytes32 salt = createSalt(deployer, "create3factory");
        bytes memory _contractCode = abi.encodePacked(type(CREATE3Factory).creationCode);

        address create3Factory = immutableMultiChainDeployer.deploy(salt, _contractCode);
    }
}
