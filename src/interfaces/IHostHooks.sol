// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

/// @notice Interface for HostHooks
interface IHostHooks is IHooks {
    /// @notice Attaches msg.sender as a symbiont to specified functions in the pool
    function attach(PoolKey calldata key, bytes4[] calldata selectors) external;

    /// @notice Detaches msg.sender as a symbiont from specified functions in the pool
    function detach(PoolKey calldata key, bytes4[] calldata selectors) external;

    /// @notice Refills the gas balance of the symbiont
    function refill() external payable;
}
