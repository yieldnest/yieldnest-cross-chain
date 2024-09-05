// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";

import {BaseData} from "script/BaseData.sol";

abstract contract BaseScript is BaseData {
    using stdJson for string;

    function setUp() public virtual override {
        super.setUp();
        console.log("BaseScript.setUp");

        // TODO: parse token address from json or as input from user
        // TODO: setup forks based on if testnet or mainnet deployment as per json
        // TODO: setup saving of deployment data in deployments json file
    }
}
