// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiChainDeployer} from "@factory/MultiChainDeployer.sol";
import {IMintableBurnableERC20} from "@interfaces/IMintableBurnableERC20.sol";
import {L1YnOFTAdapterUpgradeable} from "@adapters/L1YnOFTAdapterUpgradeable.sol";
import {L2YnERC20Upgradeable} from "@adapters/L2YnERC20Upgradeable.sol";
import {L2YnOFTAdapterUpgradeable} from "@adapters/L2YnOFTAdapterUpgradeable.sol";

contract CrossChainBaseTest is Test {
    MultiChainDeployer public multiChainDeployer;
    L1YnOFTAdapterUpgradeable public l1OFTAdapter;
    L2YnERC20Upgradeable public l2YnERC20;
    L2YnOFTAdapterUpgradeable public l2OFTAdapter;

    function setUp() public {
        multiChainDeployer = new MultiChainDeployer();
    }
}
