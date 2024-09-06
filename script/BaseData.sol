// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

contract BaseData is Script {
    struct Actors {
        address OFT_DELEGATE;
        address TOKEN_ADMIN;
        address PROXY_ADMIN;
    }

    struct ChainAddresses {
        address lzEndpoint;
    }

    struct ChainIds {
        uint256 mainnet;
        uint256 base;
        uint256 optimism;
        uint256 arbitrum;
        uint256 fraxtal;
        uint256 holesky;
        uint256 fraxtalTestnet;
    }

    mapping(uint256 => Actors) public actors;
    mapping(uint256 => ChainAddresses) public addresses;

    ChainIds public chainIds = ChainIds({
        mainnet: 1,
        base: 8453,
        optimism: 10,
        arbitrum: 42161,
        fraxtal: 252,
        holesky: 17000,
        fraxtalTestnet: 2522
    });

    function setUp() public virtual {
        addresses[chainIds.mainnet] = ChainAddresses({lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c});
        actors[chainIds.mainnet] = Actors({
            OFT_DELEGATE: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975, // yn security council
            TOKEN_ADMIN: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975,
            PROXY_ADMIN: 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975
        });

        addresses[chainIds.fraxtal] = ChainAddresses({lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c});
        actors[chainIds.fraxtal] = Actors({OFT_DELEGATE: address(0), TOKEN_ADMIN: address(0), PROXY_ADMIN: address(0)});

        addresses[chainIds.optimism] = ChainAddresses({lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c});
        actors[chainIds.optimism] = Actors({OFT_DELEGATE: address(0), TOKEN_ADMIN: address(0), PROXY_ADMIN: address(0)});

        addresses[chainIds.arbitrum] = ChainAddresses({lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c});
        actors[chainIds.arbitrum] = Actors({OFT_DELEGATE: address(0), TOKEN_ADMIN: address(0), PROXY_ADMIN: address(0)});

        addresses[chainIds.base] = ChainAddresses({lzEndpoint: 0x1a44076050125825900e736c501f859c50fE728c});
        actors[chainIds.base] = Actors({OFT_DELEGATE: address(0), TOKEN_ADMIN: address(0), PROXY_ADMIN: address(0)});

        addresses[chainIds.holesky] = ChainAddresses({lzEndpoint: 0x6EDCE65403992e310A62460808c4b910D972f10f});
        actors[chainIds.holesky] = Actors({
            OFT_DELEGATE: 0x743b91CDB1C694D4F51bCDA3a4A59DcC0d02b913, // yn security council
            TOKEN_ADMIN: 0x743b91CDB1C694D4F51bCDA3a4A59DcC0d02b913,
            PROXY_ADMIN: 0x743b91CDB1C694D4F51bCDA3a4A59DcC0d02b913
        });

        addresses[chainIds.fraxtalTestnet] = ChainAddresses({lzEndpoint: 0x6EDCE65403992e310A62460808c4b910D972f10f});
        actors[chainIds.fraxtalTestnet] =
            Actors({OFT_DELEGATE: address(0), TOKEN_ADMIN: address(0), PROXY_ADMIN: address(0)});
    }

    function getActors(uint256 chainId) public view returns (Actors memory) {
        return actors[chainId];
    }

    function getChainAddresses(uint256 chainId) public view returns (ChainAddresses memory) {
        return addresses[chainId];
    }

    function isSupportedChainId(uint256 chainId) public view returns (bool) {
        return chainId == chainIds.mainnet || chainId == chainIds.base || chainId == chainIds.fraxtal
            || chainId == chainIds.optimism || chainId == chainIds.arbitrum || chainId == chainIds.holesky
            || chainId == chainIds.fraxtalTestnet;
    }
}
