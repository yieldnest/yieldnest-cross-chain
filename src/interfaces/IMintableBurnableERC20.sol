// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMintableBurnableERC20 {
    function mint(address _to, uint256 _amount) external;
    function burnFrom(address _from, uint256 _amount) external;
}
