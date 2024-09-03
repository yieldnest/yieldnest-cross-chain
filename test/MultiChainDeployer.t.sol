// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrossChainBaseTest} from "./CrossChainBaseTest.t.sol";
import {MultiChainDeployer} from "@factory/MultiChainDeployer.sol";
import {IMintableBurnableERC20} from "@interfaces/IMintableBurnableERC20.sol";
import {L1YnOFTAdapterUpgradeable} from "@adapters/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@adapters/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@adapters/L2YnOFTAdapterUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

contract Test_MultiChainDeployer is CrossChainBaseTest {
    function test_Deployment() public view {
        assertEq(address(arbitrumDeployer), address(optimismDeployer));
        assertNotEq(address(mainnetERC20), address(0));
        assertNotEq(address(mainnetOFTAdapter), address(0));
        assertNotEq(address(arbitrumERC20), address(0));
        assertNotEq(address(arbitrumOFTAdapter), address(0));
        assertEq(address(arbitrumERC20), address(optimismERC20));
        assertEq(address(arbitrumOFTAdapter), address(optimismOFTAdapter));
    }
}
