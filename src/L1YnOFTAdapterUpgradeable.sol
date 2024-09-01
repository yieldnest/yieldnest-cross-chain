// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OFTAdapterUpgradeable} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/OFTAdapterUpgradeable.sol";
import {OFTUpgradeable} from "@layerzerolabs/lz-evm-oapp-v2/contracts-upgradeable/oft/OFTUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {RateLimiter} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

contract L1YnOFTAdapterUpgradeable is OFTAdapterUpgradeable, AccessControlUpgradeable, RateLimiter {
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
     * @param _rateLimitConfigs The rate limit configurations.
     */
    function initialize(address _owner, RateLimitConfig[] calldata _rateLimitConfigs) external virtual initializer {
        __OFTAdapter_init(_owner);
        __Ownable_init(_owner);
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _setRateLimits(_rateLimitConfigs);
    }

    /**
     * @dev Sets the rate limits for the adapter.
     * @param _rateLimitConfigs The rate limit configurations.
     */
    function setRateLimits(RateLimitConfig[] calldata _rateLimitConfigs) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRateLimits(_rateLimitConfigs);
    }

    /**
     * @dev Burns tokens from the sender's specified balance.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     */
    function _debit(uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        // @dev Check and update rate limit.
        _checkAndUpdateRateLimit(_dstEid, _amountLD);

        return super._debit(_amountLD, _minAmountLD, _dstEid);
    }
}
