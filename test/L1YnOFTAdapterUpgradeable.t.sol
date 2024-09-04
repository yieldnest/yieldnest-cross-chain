// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrossChainBaseTest} from "./CrossChainBaseTest.t.sol";
import {ImmutableMultiChainDeployer} from "@factory/ImmutableMultiChainDeployer.sol";
import {IMintableBurnableERC20} from "@interfaces/IMintableBurnableERC20.sol";
import {L1YnOFTAdapterUpgradeable} from "@adapters/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@adapters/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@adapters/L2YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

contract Test_L1YnOFTAdapterUpgradeable is CrossChainBaseTest {
    function test_L1OFTAdapterDeployment() public {}
}
