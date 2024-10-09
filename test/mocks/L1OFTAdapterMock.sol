// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {L1YnOFTAdapterUpgradeable} from "@/L1YnOFTAdapterUpgradeable.sol";
import {OFTAdapterUpgradeable} from
    "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/OFTAdapterUpgradeable.sol";
import {OFTUpgradeable} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/OFTUpgradeable.sol";

contract L1OFTAdapterMock is L1YnOFTAdapterUpgradeable {
    constructor(address _token, address _lzEndpoint) L1YnOFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    function initialize(address _owner) external virtual override initializer {
        super.__OFTAdapter_init(_owner);
        super.__Ownable_init();
        super._transferOwnership(_owner);
    }
    // @dev expose internal functions for testing purposes

    function debit(
        uint256 _amountToSendLD,
        uint256 _minAmountToCreditLD,
        uint32 _dstEid
    )
        public
        returns (uint256 amountDebitedLD, uint256 amountToCreditLD)
    {
        return _debit(_amountToSendLD, _minAmountToCreditLD, _dstEid);
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
