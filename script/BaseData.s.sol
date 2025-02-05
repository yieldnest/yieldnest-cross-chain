/* solhint-disable no-console, gas-custom-errors, var-name-mixedcase */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

contract BaseData is Script {
    struct Data {
        address OFT_OWNER;
        address TOKEN_ADMIN;
        address PROXY_ADMIN;
        address LZ_ENDPOINT;
        uint32 LZ_EID;
    }

    struct ChainIds {
        uint256 mainnet;
        uint256 base;
        uint256 optimism;
        uint256 arbitrum;
        uint256 fraxtal;
        uint256 manta;
        uint256 taiko;
        uint256 scroll;
        uint256 fantom;
        uint256 mantle;
        uint256 blast;
        uint256 linea;
        // testnets
        uint256 holesky;
        uint256 sepolia;
        uint256 fraxtalTestnet;
        uint256 morphTestnet;
    }

    mapping(uint256 => Data) private __chainIdToData;

    ChainIds private __chainIds = ChainIds({
        mainnet: 1,
        base: 8453,
        optimism: 10,
        arbitrum: 42161,
        fraxtal: 252,
        manta: 169,
        taiko: 167000,
        scroll: 534352,
        fantom: 250,
        mantle: 5000,
        blast: 81457,
        linea: 59144,
        // testnets
        holesky: 17000,
        sepolia: 11155111,
        fraxtalTestnet: 2522,
        morphTestnet: 2810
    });

    address private TEMP_YN_SECURITY_COUNCIL;

    function setUp() public virtual {
        TEMP_YN_SECURITY_COUNCIL = makeAddr("temp-yn-security-council");

        // NOTE: All the LZ Endpoints and EIDs are picked up from their docs
        // at https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts

        // mainnets
        __chainIdToData[__chainIds.mainnet] = Data({
            OFT_OWNER: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975,
            TOKEN_ADMIN: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975,
            PROXY_ADMIN: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30101
        });
        __chainIdToData[__chainIds.base] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30184
        });
        __chainIdToData[__chainIds.optimism] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30111
        });
        __chainIdToData[__chainIds.arbitrum] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30110
        });
        __chainIdToData[__chainIds.fraxtal] = Data({
            OFT_OWNER: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            TOKEN_ADMIN: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            PROXY_ADMIN: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30255
        });
        __chainIdToData[__chainIds.manta] = Data({
            OFT_OWNER: TEMP_YN_SECURITY_COUNCIL,
            TOKEN_ADMIN: TEMP_YN_SECURITY_COUNCIL,
            PROXY_ADMIN: TEMP_YN_SECURITY_COUNCIL,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30217
        });
        __chainIdToData[__chainIds.taiko] = Data({
            OFT_OWNER: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            TOKEN_ADMIN: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            PROXY_ADMIN: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30290
        });
        __chainIdToData[__chainIds.scroll] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30214
        });
        __chainIdToData[__chainIds.fantom] = Data({
            OFT_OWNER: TEMP_YN_SECURITY_COUNCIL,
            TOKEN_ADMIN: TEMP_YN_SECURITY_COUNCIL,
            PROXY_ADMIN: TEMP_YN_SECURITY_COUNCIL,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30112
        });
        __chainIdToData[__chainIds.mantle] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30181
        });
        __chainIdToData[__chainIds.blast] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30243
        });
        __chainIdToData[__chainIds.linea] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_EID: 30183
        });

        // testnets
        __chainIdToData[__chainIds.holesky] = Data({
            OFT_OWNER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            TOKEN_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            PROXY_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            LZ_ENDPOINT: 0x6EDCE65403992e310A62460808c4b910D972f10f,
            LZ_EID: 40217
        });
        __chainIdToData[__chainIds.sepolia] = Data({
            OFT_OWNER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            TOKEN_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            PROXY_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            LZ_ENDPOINT: 0x6EDCE65403992e310A62460808c4b910D972f10f,
            LZ_EID: 40161
        });
        __chainIdToData[__chainIds.fraxtalTestnet] = Data({
            OFT_OWNER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            TOKEN_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            PROXY_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            LZ_ENDPOINT: 0x6EDCE65403992e310A62460808c4b910D972f10f,
            LZ_EID: 40255
        });
        __chainIdToData[__chainIds.morphTestnet] = Data({
            OFT_OWNER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            TOKEN_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            PROXY_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            LZ_ENDPOINT: 0x6C7Ab2202C98C4227C5c46f1417D81144DA716Ff,
            LZ_EID: 40322
        });
    }

    function getData(uint256 chainId) internal view returns (Data storage _data) {
        require(isSupportedChainId(chainId), "BaseData: unsupported chainId");

        _data = __chainIdToData[chainId];
        require(_data.OFT_OWNER != address(0), "BaseData: OFT OWNER not set");
        require(_data.OFT_OWNER != TEMP_YN_SECURITY_COUNCIL, "BaseData: OFT OWNER not updated");
        require(_data.TOKEN_ADMIN != address(0), "BaseData: TOKEN ADMIN not set");
        require(_data.TOKEN_ADMIN != TEMP_YN_SECURITY_COUNCIL, "BaseData: TOKEN ADMIN not updated");
        require(_data.PROXY_ADMIN != address(0), "BaseData: PROXY ADMIN not set");
        require(_data.PROXY_ADMIN != TEMP_YN_SECURITY_COUNCIL, "BaseData: PROXY ADMIN not updated");
        require(_data.LZ_ENDPOINT != address(0), "BaseData: LZ ENDPOINT not set");
        require(_data.LZ_EID != 0, "BaseData: LZ EID not set");
    }

    function getEID(uint256 chainId) internal view returns (uint32 eid) {
        eid = getData(chainId).LZ_EID;
    }

    function isSupportedChainId(uint256 chainId) internal view returns (bool isSupported) {
        isSupported = chainId == __chainIds.mainnet || chainId == __chainIds.base || chainId == __chainIds.fraxtal
            || chainId == __chainIds.optimism || chainId == __chainIds.arbitrum || chainId == __chainIds.manta
            || chainId == __chainIds.taiko || chainId == __chainIds.scroll || chainId == __chainIds.fantom
            || chainId == __chainIds.mantle || chainId == __chainIds.blast || chainId == __chainIds.linea
        // testnets
        || chainId == __chainIds.holesky || chainId == __chainIds.fraxtalTestnet || chainId == __chainIds.sepolia
            || chainId == __chainIds.morphTestnet;
    }

    function isTestnetChainId(uint256 chainId) internal view returns (bool isTestnet) {
        isTestnet = chainId == __chainIds.holesky || chainId == __chainIds.fraxtalTestnet
            || chainId == __chainIds.sepolia || chainId == __chainIds.morphTestnet;
    }

    function getMinDelay(uint256 chainId) internal view returns (uint256 minDelay) {
        if (isTestnetChainId(chainId)) {
            return 10 minutes;
        }
        return 1 days;
    }
}
