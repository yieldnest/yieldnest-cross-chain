// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";

import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

contract L1YnOFTAdapterUpgradeable is OFTAdapterUpgradeable, RateLimiter {
    /**
     * @dev Constructor for the OFTAdapter contract.
     * @param _token The address of the ERC-20 token to be adapted.
     * @param _lzEndpoint The LayerZero endpoint address.
     */
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract
     * @param _owner The delegate capable of making OApp configurations inside of the endpoint.
     */
    function initialize(address _owner) external virtual initializer {
        __OFTAdapter_init(_owner);
        __Ownable_init(_owner);
    }

    /**
     * @dev Sets the rate limits for the adapter.
     * @param _rateLimitConfigs The rate limit configurations.
     */
    function setRateLimits(RateLimitConfig[] calldata _rateLimitConfigs) external onlyOwner {
        _setRateLimits(_rateLimitConfigs);
    }

    /**
     * @dev Burns tokens from the sender's specified balance, ie. pull method.
     * @param _from The address to debit from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     *
     * @dev msg.sender will need to approve this _amountLD of tokens to be locked inside of the contract.
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    )
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        // @dev Check and update rate limit.
        _checkAndUpdateRateLimit(_dstEid, _amountLD);

        return super._debit(_from, _amountLD, _minAmountLD, _dstEid);
    }
}
