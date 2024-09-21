// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IHostHooks} from "./IHostHooks.sol";

/// @notice Interface for SymbiontHooks
interface ISymbiontHooks is IHooks {
    /// @notice Attaches this symbiont to the specified functions of the pool via the host
    function attach(IHostHooks host, PoolKey calldata key, bytes4[] calldata selectors) external;

    /// @notice Detaches this symbiont from the specified functions of the pool via the host
    function detach(IHostHooks host, PoolKey calldata key, bytes4[] calldata selectors) external;

    /// @notice Refills the gas balance of this symbiont in the host
    function refill(IHostHooks host) external payable;
}
