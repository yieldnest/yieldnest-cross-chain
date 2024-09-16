/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

contract BaseData is Script {
    struct Addresses {
        address OFT_DELEGATE;
        address TOKEN_ADMIN;
        address PROXY_ADMIN;
        address LZ_ENDPOINT;
    }

    struct ChainIds {
        uint256 mainnet;
        uint256 base;
        uint256 optimism;
        uint256 arbitrum;
        uint256 fraxtal;
        uint256 holesky;
        uint256 sepolia;
        uint256 fraxtalTestnet;
    }

    mapping(uint256 => Addresses) private __chainIdToAddresses;

    mapping(uint256 => uint32) private __chainIdToLzEID;

    ChainIds private __chainIds = ChainIds({
        mainnet: 1,
        base: 8453,
        optimism: 10,
        arbitrum: 42161,
        fraxtal: 252,
        holesky: 17000,
        sepolia: 11155111,
        fraxtalTestnet: 2522
    });

    address private TEMP_GNOSIS_SAFE;
    address private TEMP_PROXY_CONTROLLER;

    function setUp() public virtual {
        TEMP_GNOSIS_SAFE = makeAddr("gnosis-safe");
        TEMP_PROXY_CONTROLLER = makeAddr("proxy-controller");

        // NOTE: All the LZ Addresses and EIDs are picked up from their docs
        // at https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts

        // mainnets
        __chainIdToAddresses[__chainIds.mainnet] = Addresses({
            OFT_DELEGATE: TEMP_GNOSIS_SAFE,
            TOKEN_ADMIN: TEMP_GNOSIS_SAFE,
            PROXY_ADMIN: TEMP_PROXY_CONTROLLER,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c
        });
        __chainIdToAddresses[__chainIds.base] = Addresses({
            OFT_DELEGATE: TEMP_GNOSIS_SAFE,
            TOKEN_ADMIN: TEMP_GNOSIS_SAFE,
            PROXY_ADMIN: TEMP_PROXY_CONTROLLER,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c
        });
        __chainIdToAddresses[__chainIds.optimism] = Addresses({
            OFT_DELEGATE: TEMP_GNOSIS_SAFE,
            TOKEN_ADMIN: TEMP_GNOSIS_SAFE,
            PROXY_ADMIN: TEMP_PROXY_CONTROLLER,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c
        });
        __chainIdToAddresses[__chainIds.arbitrum] = Addresses({
            OFT_DELEGATE: TEMP_GNOSIS_SAFE,
            TOKEN_ADMIN: TEMP_GNOSIS_SAFE,
            PROXY_ADMIN: TEMP_PROXY_CONTROLLER,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c
        });
        __chainIdToAddresses[__chainIds.fraxtal] = Addresses({
            OFT_DELEGATE: TEMP_GNOSIS_SAFE,
            TOKEN_ADMIN: TEMP_GNOSIS_SAFE,
            PROXY_ADMIN: TEMP_PROXY_CONTROLLER,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c
        });

        // testnets
        __chainIdToAddresses[__chainIds.holesky] = Addresses({
            OFT_DELEGATE: TEMP_GNOSIS_SAFE,
            TOKEN_ADMIN: TEMP_GNOSIS_SAFE,
            PROXY_ADMIN: TEMP_PROXY_CONTROLLER,
            LZ_ENDPOINT: 0x6EDCE65403992e310A62460808c4b910D972f10f
        });
        __chainIdToAddresses[__chainIds.sepolia] = Addresses({
            OFT_DELEGATE: TEMP_GNOSIS_SAFE,
            TOKEN_ADMIN: TEMP_GNOSIS_SAFE,
            PROXY_ADMIN: TEMP_PROXY_CONTROLLER,
            LZ_ENDPOINT: 0x6EDCE65403992e310A62460808c4b910D972f10f
        });
        __chainIdToAddresses[__chainIds.fraxtalTestnet] = Addresses({
            OFT_DELEGATE: TEMP_GNOSIS_SAFE,
            TOKEN_ADMIN: TEMP_GNOSIS_SAFE,
            PROXY_ADMIN: TEMP_PROXY_CONTROLLER,
            LZ_ENDPOINT: 0x6EDCE65403992e310A62460808c4b910D972f10f
        });

        // mainnets
        __chainIdToLzEID[__chainIds.mainnet] = 30101;
        __chainIdToLzEID[__chainIds.base] = 30184;
        __chainIdToLzEID[__chainIds.optimism] = 30111;
        __chainIdToLzEID[__chainIds.arbitrum] = 30110;
        __chainIdToLzEID[__chainIds.fraxtal] = 30255;

        // testnets
        __chainIdToLzEID[__chainIds.holesky] = 40217;
        __chainIdToLzEID[__chainIds.sepolia] = 40161;
        __chainIdToLzEID[__chainIds.fraxtalTestnet] = 40255;
    }

    function getAddresses() internal view returns (Addresses storage a) {
        require(isSupportedChainId(block.chainid), "BaseData: unsupported chainId");
        a = __chainIdToAddresses[block.chainid];
        require(a.OFT_DELEGATE != address(0), "BaseData: addresses not set");
    }

    function getEID(uint256 chainId) internal view returns (uint32) {
        require(isSupportedChainId(chainId), "BaseData: unsupported chainId");
        require(__chainIdToLzEID[chainId] != 0, "BaseData: EID not set");
        return __chainIdToLzEID[chainId];
    }

    function isSupportedChainId(uint256 chainId) internal view returns (bool) {
        bool isSupported = chainId == __chainIds.mainnet || chainId == __chainIds.base
            || chainId == __chainIds.fraxtal || chainId == __chainIds.optimism || chainId == __chainIds.arbitrum
            || chainId == __chainIds.holesky || chainId == __chainIds.fraxtalTestnet || chainId == __chainIds.sepolia;
        bool isEID = __chainIdToLzEID[chainId] != 0;
        return isSupported && isEID;
    }
}
