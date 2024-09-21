// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.27;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IHostHooks} from "./interfaces/IHostHooks.sol";
import {ISymbiontHooks} from "./interfaces/ISymbiontHooks.sol";
import {Receptor, ReceptorLibrary} from "./types/Receptor.sol";

abstract contract HostHooks is IHostHooks {
    error InvalidReceptor();

    IPoolManager private immutable s_poolManager;
    mapping(Receptor => ISymbiontHooks[]) private s_symbionts;
    mapping(ISymbiontHooks => uint256) private s_symbiontBalance;

    constructor(IPoolManager poolManager) {
        s_poolManager = poolManager;
        Hooks.validateHookPermissions(
            this,
            Hooks.Permissions(false, false, true, true, true, true, false, true, false, true, false, true, true, true)
        );
    }

    function attach(PoolKey calldata key, bytes4 selector) external {
        require(
            selector == this.beforeAddLiquidity.selector || selector == this.afterAddLiquidity.selector
                || selector == this.beforeRemoveLiquidity.selector || selector == this.afterRemoveLiquidity.selector
                || selector == this.afterSwap.selector || selector == this.afterDonate.selector,
            InvalidReceptor()
        );

        s_symbionts[ReceptorLibrary.from(key, selector)].push(ISymbiontHooks(msg.sender));
    }

    function detach(PoolKey calldata key, bytes4 selector) external {
        _detach(ReceptorLibrary.from(key, selector), ISymbiontHooks(msg.sender));
    }

    function refill() external payable {
        s_symbiontBalance[ISymbiontHooks(msg.sender)] += msg.value;
    }

    function _detach(Receptor receptor, ISymbiontHooks symbiont) private {
        uint256 symbiontsCount = s_symbionts[receptor].length;

        for (uint256 i = 0; i < symbiontsCount; i++) {
            if (s_symbionts[receptor][i] == symbiont) {
                s_symbionts[receptor][i] = s_symbionts[receptor][symbiontsCount - 1];
                s_symbionts[receptor].pop();
                return;
            }
        }
    }
}
