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

    mapping(bool => Addresses) private __addresses; // isTestnet => Actors

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

    function setUp() public virtual {
        // NOTE: All the LZ Addresses and EIDs are picked up from their docs
        // at https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts

        // mainnets
        __addresses[true] = Addresses({
            OFT_DELEGATE: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975, // yn security council
            TOKEN_ADMIN: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975,
            PROXY_ADMIN: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c
        });

        // testnets
        __addresses[false] = Addresses({
            OFT_DELEGATE: 0x743b91CDB1C694D4F51bCDA3a4A59DcC0d02b913, // yn security council
            TOKEN_ADMIN: 0x743b91CDB1C694D4F51bCDA3a4A59DcC0d02b913,
            PROXY_ADMIN: 0x743b91CDB1C694D4F51bCDA3a4A59DcC0d02b913,
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

    function getAddresses() internal view returns (Addresses storage) {
        require(isSupportedChainId(block.chainid), "BaseData: unsupported chainId");
        return __addresses[!isTestnet()];
    }

    function getEID(uint256 chainId) internal view returns (uint32) {
        require(isSupportedChainId(chainId), "BaseData: unsupported chainId");
        return __chainIdToLzEID[chainId];
    }

    function isSupportedChainId(uint256 chainId) internal view returns (bool) {
        bool isSupported = chainId == __chainIds.mainnet || chainId == __chainIds.base
            || chainId == __chainIds.fraxtal || chainId == __chainIds.optimism || chainId == __chainIds.arbitrum
            || chainId == __chainIds.holesky || chainId == __chainIds.fraxtalTestnet || chainId == __chainIds.sepolia;
        bool isEID = __chainIdToLzEID[chainId] != 0;
        return isSupported && isEID;
    }

    function isTestnet() internal view returns (bool) {
        return block.chainid == __chainIds.holesky || block.chainid == __chainIds.fraxtalTestnet
            || block.chainid == __chainIds.sepolia;
    }
}
