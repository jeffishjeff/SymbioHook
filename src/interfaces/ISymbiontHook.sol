// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IHostHook, IHooks, Hooks, PoolKey} from "./IHostHook.sol";
import {Currency} from "v4-core/types/Currency.sol";

interface ISymbiontHook is IHooks {
    function attach(IHostHook host, PoolKey calldata key, Hooks.Permissions calldata permissions) external;
    function detach(IHostHook host, PoolKey calldata key, Hooks.Permissions calldata permissions) external;

    function refill(IHostHook host, Currency currency, uint256 amount) external payable;
}
