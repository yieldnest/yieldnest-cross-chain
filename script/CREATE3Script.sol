// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {ICREATE3Factory} from "@create3-factory/ICREATE3Factory.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";

// @dev This contract is used to deploy contracts and proxies using CREATE3.
//      It should be inherited by the script that deploys the contracts, it shouldn't be used directly or as a
// library.
abstract contract CREATE3Script {
    ICREATE3Factory public constant CREATE3_FACTORY = ICREATE3Factory(0x3Ab34A5758F42080A536865aD3a7D35E92861418);

    function deployProxy(
        bytes32 _salt,
        address _implementation,
        address _initialOwner,
        bytes memory _initializeArgs
    )
        public
        returns (address proxy)
    {
        bytes memory _constructorParams = abi.encode(_implementation, _initialOwner, _initializeArgs);
        bytes memory _contractCode =
            abi.encodePacked(type(TransparentUpgradeableProxy).creationCode, _constructorParams);
        proxy = CREATE3_FACTORY.deploy(_salt, _contractCode);
    }

    function deployL1YnOFTAdapter(
        bytes32 _proxySalt,
        address _token,
        address _lzEndpoint,
        address _owner,
        address _proxyController
    )
        public
        returns (address deployedContract)
    {
        bytes memory _initializeArgs =
            abi.encodeWithSelector(L1YnOFTAdapterUpgradeable.initialize.selector, _owner);
        address _implAddr = address(new L1YnOFTAdapterUpgradeable(_token, _lzEndpoint));
        deployedContract = deployProxy(_proxySalt, _implAddr, _proxyController, _initializeArgs);
    }

    function deployL2YnOFTAdapter(
        bytes32 _proxySalt,
        address _token,
        address _lzEndpoint,
        address _owner,
        address _proxyController
    )
        public
        returns (address deployedContract)
    {
        bytes memory _initializeArgs =
            abi.encodeWithSelector(L2YnOFTAdapterUpgradeable.initialize.selector, _owner);
        address _implAddr = address(new L2YnOFTAdapterUpgradeable(_token, _lzEndpoint));
        deployedContract = deployProxy(_proxySalt, _implAddr, _proxyController, _initializeArgs);
    }

    function deployL2YnERC20(
        bytes32 _proxySalt,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _owner,
        address _proxyController
    )
        public
        returns (address deployedContract)
    {
        bytes memory _initializeArgs =
            abi.encodeWithSelector(L2YnERC20Upgradeable.initialize.selector, _name, _symbol, _decimals, _owner);
        address _implAddr = address(new L2YnERC20Upgradeable());
        deployedContract = deployProxy(_proxySalt, _implAddr, _proxyController, _initializeArgs);
    }
}
