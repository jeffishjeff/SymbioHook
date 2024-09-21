// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IHostHooks} from "./interfaces/IHostHooks.sol";
import {BaseSymbiontHook} from "./BaseSymbiontHook.sol";

contract DampenedOracleSymbiontHook is BaseSymbiontHook {
    using StateLibrary for IPoolManager;

    error AccessDenied();

    uint256 private constant ADJUSTMENT_LIMIT_BPS = 100; // adjust the oracle price by at most 1% per symbiont call
    uint256 private constant BPS_DENOMINATOR = 10_000;

    IHostHooks private immutable s_host;
    address private immutable s_owner;
    mapping(PoolId => uint256) private s_sqrtPricesX96;

    modifier onlyOwner() {
        require(msg.sender == s_owner, AccessDenied());
        _;
    }

    modifier onlyHost() {
        require(msg.sender == address(s_host), AccessDenied());
        _;
    }

    constructor(IHostHooks host) {
        s_host = host;
        s_owner = msg.sender;
    }

    // Attach this symbiont to the pools' afterSwap hook via the host
    function attach(PoolKey[] calldata keys) external onlyOwner {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = this.afterSwap.selector;

        for (uint256 i = 0; i < keys.length; i++) {
            s_host.attach(keys[i], selectors);
        }
    }

    // Detach this symbiont from the pools' afterSwap hook via the host
    function detach(PoolKey[] calldata keys) external onlyOwner {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = this.afterSwap.selector;

        for (uint256 i = 0; i < keys.length; i++) {
            s_host.detach(keys[i], selectors);
        }
    }

    // Refill the gas balance of the symbiont
    function refill() external payable onlyOwner {
        s_host.refill{value: msg.value}();
    }

    // Set the oracle sqrt price for the pool in x96 format
    function consult(PoolKey calldata key) external view returns (uint256) {
        return s_sqrtPricesX96[key.toId()];
    }

    /// @inheritdoc IHooks
    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        returns (bytes4, int128)
    {
        PoolId poolId = key.toId();

        uint256 lastSqrtPriceX96 = s_sqrtPricesX96[poolId];
        (uint256 currentSqrtPriceX96,,,) = s_host.poolManager().getSlot0(poolId);

        if (lastSqrtPriceX96 == 0) {
            // First price update, set the price to the initial price
            s_sqrtPricesX96[poolId] = currentSqrtPriceX96;
        } else {
            uint256 stepX96 = lastSqrtPriceX96 * ADJUSTMENT_LIMIT_BPS / BPS_DENOMINATOR;

            if (currentSqrtPriceX96 > lastSqrtPriceX96 + stepX96) {
                s_sqrtPricesX96[poolId] = lastSqrtPriceX96 + stepX96;
            } else if (currentSqrtPriceX96 < lastSqrtPriceX96 - stepX96) {
                s_sqrtPricesX96[poolId] = lastSqrtPriceX96 - stepX96;
            } else {
                s_sqrtPricesX96[poolId] = currentSqrtPriceX96;
            }
        }

        return (this.afterSwap.selector, 0);
    }
}
