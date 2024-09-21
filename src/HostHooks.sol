// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.27;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHostHooks} from "./interfaces/IHostHooks.sol";
import {ISymbiontHooks} from "./interfaces/ISymbiontHooks.sol";
import {Receptor} from "./types/Receptor.sol";

abstract contract HostHooks is IHostHooks {
    struct SymbiontState {
        uint256 gasBalance;
        uint128 currency0Balance;
        uint128 currency1Balance;
    }

    IPoolManager private immutable s_poolManager;
    mapping(Receptor => ISymbiontHooks[]) private s_symbionts;
    mapping(ISymbiontHooks => SymbiontState) private s_symbiontStates;

    constructor(IPoolManager poolManager) {
        s_poolManager = poolManager;
        Hooks.validateHookPermissions(
            this,
            Hooks.Permissions(false, false, true, true, true, true, false, true, false, true, false, true, true, true)
        );
    }
}
