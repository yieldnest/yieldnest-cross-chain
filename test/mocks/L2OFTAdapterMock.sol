// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {L2YnOFTAdapterUpgradeable} from "@/L2YnOFTAdapterUpgradeable.sol";

contract L2OFTAdapterMock is L2YnOFTAdapterUpgradeable {
    constructor(address _token, address _lzEndpoint) L2YnOFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    function initialize(address _owner) external virtual override initializer {
        super.__OFTAdapter_init(_owner);
        super.__Ownable_init(_owner);
    }

    // added a reinitialize function to allow for testing upgrades
    // solhint-disable-next-line no-empty-blocks
    function reinitialize() external reinitializer(2) {}

    function mock() external pure returns (uint256) {
        return 1;
    }

    // @dev expose internal functions for testing purposes
    function debit(
        address _from,
        uint256 _amountToSendLD,
        uint256 _minAmountToCreditLD,
        uint32 _dstEid
    )
        public
        returns (uint256 amountDebitedLD, uint256 amountToCreditLD)
    {
        return _debit(_from, _amountToSendLD, _minAmountToCreditLD, _dstEid);
    }

    function debitView(
        uint256 _amountToSendLD,
        uint256 _minAmountToCreditLD,
        uint32 _dstEid
    )
        public
        view
        returns (uint256 amountDebitedLD, uint256 amountToCreditLD)
    {
        return _debitView(_amountToSendLD, _minAmountToCreditLD, _dstEid);
    }

    function credit(
        address _to,
        uint256 _amountToCreditLD,
        uint32 _srcEid
    )
        public
        returns (uint256 amountReceivedLD)
    {
        return _credit(_to, _amountToCreditLD, _srcEid);
    }

    function removeDust(uint256 _amountLD) public view returns (uint256 amountLD) {
        return _removeDust(_amountLD);
    }
}
