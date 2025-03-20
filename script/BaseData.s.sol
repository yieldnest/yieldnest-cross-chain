/* solhint-disable no-console, gas-custom-errors, var-name-mixedcase */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

contract BaseData is Script {
    struct Data {
        address OFT_OWNER;
        address TOKEN_ADMIN;
        address PROXY_ADMIN;
        uint32 LZ_EID;
        address LZ_ENDPOINT;
        address LZ_SEND_LIB;
        address LZ_RECEIVE_LIB;
        address LZ_DVN;
        address NETHERMIND_DVN;
        address LZ_EXECUTOR;
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
        uint256 bera;
        uint256 binance;
        uint256 hemi;
        // testnets
        uint256 holesky;
        uint256 sepolia;
        uint256 fraxtalTestnet;
        uint256 morphTestnet;
        uint256 hemiTestnet;
        uint256 binanceTestnet;
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
        bera: 80094,
        binance: 56,
        hemi: 43111,
        // testnets
        holesky: 17000,
        sepolia: 11155111,
        fraxtalTestnet: 2522,
        morphTestnet: 2810,
        hemiTestnet: 743111,
        binanceTestnet: 97
    });

    function setUp() public virtual {
        // NOTE: All the LZ Endpoints and EIDs are picked up from their docs
        // at https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts

        // mainnets
        __chainIdToData[__chainIds.mainnet] = Data({
            OFT_OWNER: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975,
            TOKEN_ADMIN: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975,
            PROXY_ADMIN: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1,
            LZ_RECEIVE_LIB: 0xc02Ab410f0734EFa3F14628780e6e695156024C2,
            LZ_DVN: 0x589dEDbD617e0CBcB916A9223F4d1300c294236b,
            NETHERMIND_DVN: 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5,
            LZ_EXECUTOR: 0x173272739Bd7Aa6e4e214714048a9fE699453059,
            LZ_EID: 30101
        });
        __chainIdToData[__chainIds.base] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2,
            LZ_RECEIVE_LIB: 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf,
            LZ_DVN: 0x9e059a54699a285714207b43B055483E78FAac25,
            NETHERMIND_DVN: 0xcd37CA043f8479064e10635020c65FfC005d36f6,
            LZ_EXECUTOR: 0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4,
            LZ_EID: 30184
        });
        __chainIdToData[__chainIds.optimism] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0x1322871e4ab09Bc7f5717189434f97bBD9546e95,
            LZ_RECEIVE_LIB: 0x3c4962Ff6258dcfCafD23a814237B7d6Eb712063,
            LZ_DVN: 0x6A02D83e8d433304bba74EF1c427913958187142,
            NETHERMIND_DVN: 0xa7b5189bcA84Cd304D8553977c7C614329750d99,
            LZ_EXECUTOR: 0x2D2ea0697bdbede3F01553D2Ae4B8d0c486B666e,
            LZ_EID: 30111
        });
        __chainIdToData[__chainIds.arbitrum] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0x975bcD720be66659e3EB3C0e4F1866a3020E493A,
            LZ_RECEIVE_LIB: 0x7B9E184e07a6EE1aC23eAe0fe8D6Be2f663f05e6,
            LZ_DVN: 0x2f55C492897526677C5B68fb199ea31E2c126416,
            NETHERMIND_DVN: 0xa7b5189bcA84Cd304D8553977c7C614329750d99,
            LZ_EXECUTOR: 0x31CAe3B7fB82d847621859fb1585353c5720660D,
            LZ_EID: 30110
        });
        __chainIdToData[__chainIds.fraxtal] = Data({
            OFT_OWNER: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            TOKEN_ADMIN: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            PROXY_ADMIN: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0x377530cdA84DFb2673bF4d145DCF0C4D7fdcB5b6,
            LZ_RECEIVE_LIB: 0x8bC1e36F015b9902B54b1387A4d733cebc2f5A4e,
            LZ_DVN: 0xcCE466a522984415bC91338c232d98869193D46e,
            NETHERMIND_DVN: 0xa7b5189bcA84Cd304D8553977c7C614329750d99,
            LZ_EXECUTOR: 0x41Bdb4aa4A63a5b2Efc531858d3118392B1A1C3d,
            LZ_EID: 30255
        });
        __chainIdToData[__chainIds.manta] = Data({
            OFT_OWNER: address(0),
            TOKEN_ADMIN: address(0),
            PROXY_ADMIN: address(0),
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0xD1654C656455E40E2905E96b6B91088AC2B362a2,
            LZ_RECEIVE_LIB: 0xC1EC25A9e8a8DE5Aa346f635B33e5B74c4c081aF,
            LZ_DVN: 0xA09dB5142654e3eB5Cf547D66833FAe7097B21C3,
            NETHERMIND_DVN: 0x247624e2143504730aeC22912ed41F092498bEf2,
            LZ_EXECUTOR: 0x8DD9197E51dC6082853aD71D35912C53339777A7,
            LZ_EID: 30217
        });
        __chainIdToData[__chainIds.taiko] = Data({
            OFT_OWNER: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            TOKEN_ADMIN: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            PROXY_ADMIN: 0x3F95ce491748a3E04755332c8d52Ec4F02deE096,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0xc1B621b18187F74c8F6D52a6F709Dd2780C09821,
            LZ_RECEIVE_LIB: 0x377530cdA84DFb2673bF4d145DCF0C4D7fdcB5b6,
            LZ_DVN: 0xc097ab8CD7b053326DFe9fB3E3a31a0CCe3B526f,
            NETHERMIND_DVN: 0xDd7B5E1dB4AaFd5C8EC3b764eFB8ed265Aa5445B,
            LZ_EXECUTOR: 0xa20DB4Ffe74A31D17fc24BD32a7DD7555441058e,
            LZ_EID: 30290
        });
        __chainIdToData[__chainIds.scroll] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0x9BbEb2B2184B9313Cf5ed4a4DDFEa2ef62a2a03B,
            LZ_RECEIVE_LIB: 0x8363302080e711E0CAb978C081b9e69308d49808,
            LZ_DVN: 0xbe0d08a85EeBFCC6eDA0A843521f7CBB1180D2e2,
            NETHERMIND_DVN: 0x446755349101cB20c582C224462c3912d3584dCE,
            LZ_EXECUTOR: 0x581b26F362AD383f7B51eF8A165Efa13DDe398a4,
            LZ_EID: 30214
        });
        __chainIdToData[__chainIds.fantom] = Data({
            OFT_OWNER: address(0),
            TOKEN_ADMIN: address(0),
            PROXY_ADMIN: address(0),
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0xC17BaBeF02a937093363220b0FB57De04A535D5E,
            LZ_RECEIVE_LIB: 0xe1Dd69A2D08dF4eA6a30a91cC061ac70F98aAbe3,
            LZ_DVN: 0xE60A3959Ca23a92BF5aAf992EF837cA7F828628a,
            NETHERMIND_DVN: 0x31F748a368a893Bdb5aBB67ec95F232507601A73,
            LZ_EXECUTOR: 0x2957eBc0D2931270d4a539696514b047756b3056,
            LZ_EID: 30112
        });
        __chainIdToData[__chainIds.mantle] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0xde19274c009A22921E3966a1Ec868cEba40A5DaC,
            LZ_RECEIVE_LIB: 0x8da6512De9379fBF4F09BF520Caf7a85435ed93e,
            LZ_DVN: 0x28B6140ead70cb2Fb669705b3598ffB4BEaA060b,
            NETHERMIND_DVN: 0xB19A9370D404308040A9760678c8Ca28aFfbbb76,
            LZ_EXECUTOR: 0x4Fc3f4A38Acd6E4cC0ccBc04B3Dd1CCAeFd7F3Cd,
            LZ_EID: 30181
        });
        __chainIdToData[__chainIds.blast] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0xc1B621b18187F74c8F6D52a6F709Dd2780C09821,
            LZ_RECEIVE_LIB: 0x377530cdA84DFb2673bF4d145DCF0C4D7fdcB5b6,
            LZ_DVN: 0xc097ab8CD7b053326DFe9fB3E3a31a0CCe3B526f,
            NETHERMIND_DVN: 0xDd7B5E1dB4AaFd5C8EC3b764eFB8ed265Aa5445B,
            LZ_EXECUTOR: 0x4208D6E27538189bB48E603D6123A94b8Abe0A0b,
            LZ_EID: 30243
        });
        __chainIdToData[__chainIds.linea] = Data({
            OFT_OWNER: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            TOKEN_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            PROXY_ADMIN: 0xCb343bF07E72548349f506593336b6CB698Ad6dA,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0x32042142DD551b4EbE17B6FEd53131dd4b4eEa06,
            LZ_RECEIVE_LIB: 0xE22ED54177CE1148C557de74E4873619e6c6b205,
            LZ_DVN: 0x129Ee430Cb2Ff2708CCADDBDb408a88Fe4FFd480,
            NETHERMIND_DVN: 0xDd7B5E1dB4AaFd5C8EC3b764eFB8ed265Aa5445B,
            LZ_EXECUTOR: 0x0408804C5dcD9796F22558464E6fE5bDdF16A7c7,
            LZ_EID: 30183
        });
        __chainIdToData[__chainIds.bera] = Data({
            OFT_OWNER: 0xae495b70D00C724e5a9E23F4613d5e8139677503,
            TOKEN_ADMIN: 0xae495b70D00C724e5a9E23F4613d5e8139677503,
            PROXY_ADMIN: 0xae495b70D00C724e5a9E23F4613d5e8139677503,
            LZ_ENDPOINT: 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B,
            LZ_SEND_LIB: 0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7,
            LZ_RECEIVE_LIB: 0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043,
            LZ_DVN: 0x282b3386571f7f794450d5789911a9804FA346b4,
            NETHERMIND_DVN: 0xDd7B5E1dB4AaFd5C8EC3b764eFB8ed265Aa5445B,
            LZ_EXECUTOR: 0x4208D6E27538189bB48E603D6123A94b8Abe0A0b,
            LZ_EID: 30362
        });
        __chainIdToData[__chainIds.binance] = Data({
            OFT_OWNER: 0x721688652DEa9Cabec70BD99411EAEAB9485d436,
            TOKEN_ADMIN: 0x721688652DEa9Cabec70BD99411EAEAB9485d436,
            PROXY_ADMIN: 0x721688652DEa9Cabec70BD99411EAEAB9485d436,
            LZ_ENDPOINT: 0x1a44076050125825900e736c501f859c50fE728c,
            LZ_SEND_LIB: 0x9F8C645f2D0b2159767Bd6E0839DE4BE49e823DE,
            LZ_RECEIVE_LIB: 0xB217266c3A98C8B2709Ee26836C98cf12f6cCEC1,
            LZ_DVN: 0xfD6865c841c2d64565562fCc7e05e619A30615f0,
            NETHERMIND_DVN: 0x31F748a368a893Bdb5aBB67ec95F232507601A73,
            LZ_EXECUTOR: 0x3ebD570ed38B1b3b4BC886999fcF507e9D584859,
            LZ_EID: 30102
        });
        __chainIdToData[__chainIds.hemi] = Data({
            OFT_OWNER: 0x54d4F70a7a8f4E5209F8B21cC4e88440B9192160,
            TOKEN_ADMIN: 0x54d4F70a7a8f4E5209F8B21cC4e88440B9192160,
            PROXY_ADMIN: 0x54d4F70a7a8f4E5209F8B21cC4e88440B9192160,
            LZ_ENDPOINT: 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B,
            LZ_SEND_LIB: 0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7,
            LZ_RECEIVE_LIB: 0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043,
            LZ_DVN: 0x282b3386571f7f794450d5789911a9804FA346b4,
            NETHERMIND_DVN: 0x07C05EaB7716AcB6f83ebF6268F8EECDA8892Ba1,
            LZ_EXECUTOR: 0x4208D6E27538189bB48E603D6123A94b8Abe0A0b,
            LZ_EID: 30329
        });

        // testnets
        __chainIdToData[__chainIds.holesky] = Data({
            OFT_OWNER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            TOKEN_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            PROXY_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            LZ_ENDPOINT: 0x6EDCE65403992e310A62460808c4b910D972f10f,
            LZ_SEND_LIB: 0x21F33EcF7F65D61f77e554B4B4380829908cD076,
            LZ_RECEIVE_LIB: 0xbAe52D605770aD2f0D17533ce56D146c7C964A0d,
            LZ_DVN: 0x3E43f8ff0175580f7644DA043071c289DDf98118,
            NETHERMIND_DVN: address(0),
            LZ_EXECUTOR: 0xBc0C24E6f24eC2F1fd7E859B8322A1277F80aaD5,
            LZ_EID: 40217
        });
        __chainIdToData[__chainIds.sepolia] = Data({
            OFT_OWNER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            TOKEN_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            PROXY_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            LZ_ENDPOINT: 0x6EDCE65403992e310A62460808c4b910D972f10f,
            LZ_SEND_LIB: 0xcc1ae8Cf5D3904Cef3360A9532B477529b177cCE,
            LZ_RECEIVE_LIB: 0xdAf00F5eE2158dD58E0d3857851c432E34A3A851,
            LZ_DVN: 0x8eebf8b423B73bFCa51a1Db4B7354AA0bFCA9193,
            NETHERMIND_DVN: 0x68802e01D6321D5159208478f297d7007A7516Ed,
            LZ_EXECUTOR: 0x718B92b5CB0a5552039B593faF724D182A881eDA,
            LZ_EID: 40161
        });
        __chainIdToData[__chainIds.fraxtalTestnet] = Data({
            OFT_OWNER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            TOKEN_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            PROXY_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            LZ_ENDPOINT: 0x6EDCE65403992e310A62460808c4b910D972f10f,
            LZ_SEND_LIB: 0xd682ECF100f6F4284138AA925348633B0611Ae21,
            LZ_RECEIVE_LIB: 0xcF1B0F4106B0324F96fEfcC31bA9498caa80701C,
            LZ_DVN: 0xF49d162484290EAeAd7bb8C2c7E3a6f8f52e32d6,
            NETHERMIND_DVN: 0x14CcB1a6ebb0b6F669fcE087a2DbF664A1F57251,
            LZ_EXECUTOR: 0x55c175DD5b039331dB251424538169D8495C18d1,
            LZ_EID: 40255
        });
        __chainIdToData[__chainIds.morphTestnet] = Data({
            OFT_OWNER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            TOKEN_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            PROXY_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            LZ_ENDPOINT: 0x6C7Ab2202C98C4227C5c46f1417D81144DA716Ff,
            LZ_SEND_LIB: 0xd682ECF100f6F4284138AA925348633B0611Ae21,
            LZ_RECEIVE_LIB: 0xcF1B0F4106B0324F96fEfcC31bA9498caa80701C,
            LZ_DVN: 0xF49d162484290EAeAd7bb8C2c7E3a6f8f52e32d6,
            NETHERMIND_DVN: address(0),
            LZ_EXECUTOR: 0x701f3927871EfcEa1235dB722f9E608aE120d243,
            LZ_EID: 40322
        });
        __chainIdToData[__chainIds.hemiTestnet] = Data({
            OFT_OWNER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            TOKEN_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            PROXY_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            LZ_ENDPOINT: 0x6C7Ab2202C98C4227C5c46f1417D81144DA716Ff,
            LZ_SEND_LIB: 0xd682ECF100f6F4284138AA925348633B0611Ae21,
            LZ_RECEIVE_LIB: 0xcF1B0F4106B0324F96fEfcC31bA9498caa80701C,
            LZ_DVN: 0xC1868e054425D378095A003EcbA3823a5D0135C9,
            NETHERMIND_DVN: 0xF49d162484290EAeAd7bb8C2c7E3a6f8f52e32d6, //no listed nethermind testnet dvn, using
                // LZ's dvn
            LZ_EXECUTOR: 0x701f3927871EfcEa1235dB722f9E608aE120d243,
            LZ_EID: 40338
        });
        __chainIdToData[__chainIds.binanceTestnet] = Data({
            OFT_OWNER: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            TOKEN_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            PROXY_ADMIN: 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5,
            LZ_ENDPOINT: 0x6EDCE65403992e310A62460808c4b910D972f10f,
            LZ_SEND_LIB: 0x55f16c442907e86D764AFdc2a07C2de3BdAc8BB7,
            LZ_RECEIVE_LIB: 0x188d4bbCeD671A7aA2b5055937F79510A32e9683,
            LZ_DVN: 0x0eE552262f7B562eFcED6DD4A7e2878AB897d405,
            NETHERMIND_DVN: 0x6334290B7b4a365F3c0E79c85B1b42F078db78E4,
            LZ_EXECUTOR: 0x31894b190a8bAbd9A067Ce59fde0BfCFD2B18470,
            LZ_EID: 40102
        });
    }

    function getData(uint256 chainId) internal view returns (Data storage _data) {
        require(isSupportedChainId(chainId), "BaseData: unsupported chainId");

        _data = __chainIdToData[chainId];
        require(_data.OFT_OWNER != address(0), "BaseData: OFT OWNER not set");
        require(_data.TOKEN_ADMIN != address(0), "BaseData: TOKEN ADMIN not set");
        require(_data.PROXY_ADMIN != address(0), "BaseData: PROXY ADMIN not set");
        require(_data.LZ_ENDPOINT != address(0), "BaseData: LZ ENDPOINT not set");
        require(_data.LZ_SEND_LIB != address(0), "BaseData: LZ_SEND_LIB not set");
        require(_data.LZ_RECEIVE_LIB != address(0), "BaseData: LZ_RECEIVE_LIB not set");
        require(_data.LZ_DVN != address(0), "BaseData: LZ DVN not set");
        if (!isTestnetChainId(chainId)) {
            require(_data.NETHERMIND_DVN != address(0), "BaseData: NETHERMIND DVN not set");
        }
        require(_data.LZ_EXECUTOR != address(0), "BaseData: LZ EXECUTOR not set");
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
            || chainId == __chainIds.bera || chainId == __chainIds.binance || chainId == __chainIds.hemi
        // testnets
        || chainId == __chainIds.holesky || chainId == __chainIds.fraxtalTestnet || chainId == __chainIds.sepolia
            || chainId == __chainIds.morphTestnet || chainId == __chainIds.hemiTestnet
            || chainId == __chainIds.binanceTestnet;
    }

    function isTestnetChainId(uint256 chainId) internal view returns (bool isTestnet) {
        isTestnet = chainId == __chainIds.holesky || chainId == __chainIds.fraxtalTestnet
            || chainId == __chainIds.sepolia || chainId == __chainIds.morphTestnet || chainId == __chainIds.hemiTestnet
            || chainId == __chainIds.binanceTestnet;
    }

    function getMinDelay(uint256 chainId) internal view returns (uint256 minDelay) {
        if (isTestnetChainId(chainId)) {
            return 10 minutes;
        }
        return 1 days;
    }
}
