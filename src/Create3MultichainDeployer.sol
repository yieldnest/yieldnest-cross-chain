// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OFTAdapterUpgradeable} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/OFTAdapterUpgradeable.sol";
import {OFTUpgradeable} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/OFTUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

contract Create3MultiChainDeployer is OFTAdapterUpgradeable, AccessControlUpgradeable, RateLimiter {}
