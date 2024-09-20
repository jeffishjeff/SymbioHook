// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IHooks, Hooks, PoolKey} from "v4-core/libraries/Hooks.sol";
import {Currency} from "v4-core/types/Currency.sol";

interface IHostHook is IHooks {
    function attach(PoolKey calldata key, Hooks.Permissions calldata permissions) external;
    function detach(PoolKey calldata key, Hooks.Permissions calldata permissions) external;

    function sync(Currency currency) external;
    function refill() external payable;
}
