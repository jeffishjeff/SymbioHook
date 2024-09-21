// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {CurrencyLibrary} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IHostHooks} from "./interfaces/IHostHooks.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Receptor, ReceptorLibrary} from "./types/Receptor.sol";
import {BaseHostHook} from "./BaseHostHook.sol";

contract DoubleGasRebateHostHook is IHostHooks, BaseHostHook {
    uint256 private constant GAS_LIMIT_BPS = 100; // gas limit per symbiont call, 1% of block gas limit
    uint256 private constant GAS_REBATE_MULTIPLIER_BPS = 20_000; // gas rebate = 200% of gas consumed in a symbiont call
    uint256 private constant BPS_DENOMINATOR = 10_000;

    mapping(Receptor => IHooks[]) private s_receptorSymbionts; // list of symbionts attached to a receptor
    mapping(IHooks => uint256) private s_symbiontBalances; // gas balance of a symbiont

    constructor(IPoolManager _poolManager)
        BaseHostHook(
            _poolManager,
            Hooks.Permissions(false, false, true, true, true, true, false, true, false, true, false, false, false, false)
        )
    {}

    /// @inheritdoc IHostHooks
    function attach(PoolKey calldata key, bytes4[] calldata selectors) external {
        for (uint256 i = 0; i < selectors.length; i++) {
            s_receptorSymbionts[ReceptorLibrary.from(key, selectors[i])].push(IHooks(msg.sender));
        }
    }

    /// @inheritdoc IHostHooks
    function detach(PoolKey calldata key, bytes4[] calldata selectors) external {
        for (uint256 i = 0; i < selectors.length; i++) {
            _detach(ReceptorLibrary.from(key, selectors[i]), IHooks(msg.sender));
        }
    }

    /// @inheritdoc IHostHooks
    function refill() external payable {
        s_symbiontBalances[IHooks(msg.sender)] += msg.value;
    }

    /// @inheritdoc IHostHooks
    function poolManager() external view override returns (IPoolManager) {
        return s_poolManager;
    }

    /// @inheritdoc IHostHooks
    function symbionts(PoolKey calldata key, bytes4 selector) external view override returns (IHooks[] memory) {
        return s_receptorSymbionts[ReceptorLibrary.from(key, selector)];
    }

    /// @inheritdoc IHostHooks
    function balanceOf(IHooks symbiont) external view override returns (uint256) {
        return s_symbiontBalances[symbiont];
    }

    /// @inheritdoc IHooks
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        _callSymbiontsAndGiveGasRebate(
            ReceptorLibrary.from(key, this.beforeAddLiquidity.selector),
            abi.encodeCall(IHooks.beforeAddLiquidity, (sender, key, params, hookData)),
            sender
        );

        return this.beforeAddLiquidity.selector;
    }

    /// @inheritdoc IHooks
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        _callSymbiontsAndGiveGasRebate(
            ReceptorLibrary.from(key, this.afterAddLiquidity.selector),
            abi.encodeCall(IHooks.afterAddLiquidity, (sender, key, params, delta, feesAccrued, hookData)),
            sender
        );

        // TODO: aggregate and return balance deltas from symbionts
        return (this.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /// @inheritdoc IHooks
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        _callSymbiontsAndGiveGasRebate(
            ReceptorLibrary.from(key, this.beforeRemoveLiquidity.selector),
            abi.encodeCall(IHooks.beforeRemoveLiquidity, (sender, key, params, hookData)),
            sender
        );

        return this.beforeRemoveLiquidity.selector;
    }

    /// @inheritdoc IHooks
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        _callSymbiontsAndGiveGasRebate(
            ReceptorLibrary.from(key, this.afterRemoveLiquidity.selector),
            abi.encodeCall(IHooks.afterRemoveLiquidity, (sender, key, params, delta, feesAccrued, hookData)),
            sender
        );

        // TODO: aggregate and return balance deltas from symbionts
        return (this.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /// @inheritdoc IHooks
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        _callSymbiontsAndGiveGasRebate(
            ReceptorLibrary.from(key, this.afterSwap.selector),
            abi.encodeCall(IHooks.afterSwap, (sender, key, params, delta, hookData)),
            sender
        );

        // TODO: aggregate and return unspecified delta from symbionts
        return (this.afterSwap.selector, 0);
    }

    /// @inheritdoc IHooks
    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external override returns (bytes4) {
        _callSymbiontsAndGiveGasRebate(
            ReceptorLibrary.from(key, this.afterDonate.selector),
            abi.encodeCall(IHooks.afterDonate, (sender, key, amount0, amount1, hookData)),
            sender
        );

        return this.afterDonate.selector;
    }

    /// @notice Helper function to detach a symbiont from a receptor
    function _detach(Receptor receptor, IHooks symbiont) private {
        IHooks[] storage s_symbionts = s_receptorSymbionts[receptor];

        for (uint256 i = 0; i < s_symbionts.length; i++) {
            if (s_symbionts[i] == symbiont) {
                s_symbionts[i] = s_symbionts[s_symbionts.length - 1];
                s_symbionts.pop();
                return;
            }
        }
    }

    /// @notice Helper function for calling a symbiont, check for success but do not revert
    function _callSymbiont(IHooks symbiont, bytes memory data, uint256 gasLimit)
        private
        returns (bool success, bytes memory result)
    {
        assembly ("memory-safe") {
            success := call(gasLimit, symbiont, 0, add(data, 0x20), mload(data), 0, 0)
            success := and(success, gt(returndatasize(), 31))

            // continue if call succeeds with return data
            if success {
                result := mload(0x40)
                mstore(0x40, add(result, and(add(returndatasize(), 0x3f), not(0x1f))))
                mstore(result, returndatasize())
                returndatacopy(add(result, 0x20), 0, returndatasize())

                // ensure the correct selector is returned
                // success := and(success, eq(mload(add(data, 0x20)), mload(add(result, 0x20))))
            }
        }
    }

    /// @notice Helper function to call symbionts attached to a receptor, and give gas rebate to recipient
    function _callSymbiontsAndGiveGasRebate(Receptor receptor, bytes memory data, address recipient) private {
        uint256 gasLimit = (block.gaslimit * GAS_LIMIT_BPS) / BPS_DENOMINATOR; // gas allowed per symbiont call, 1% of block gas limit
        IHooks[] storage s_symbionts = s_receptorSymbionts[receptor];

        uint256 totalGasRebate;
        // sload length each time as the array may change
        for (uint256 i = 0; i < s_symbionts.length;) {
            uint256 gasBefore = gasleft();
            if (gasBefore < gasLimit) break; // stop if not enough gas left

            IHooks symbiont = s_symbionts[i];
            uint256 balance = s_symbiontBalances[symbiont];

            if (balance < gasLimit) {
                _detach(receptor, symbiont); // detach symbiont if not enough balance, do not increment i
            } else {
                (bool success,) = _callSymbiont(symbiont, data, gasLimit);

                if (!success) {
                    _detach(receptor, symbiont); // detach symbiont if call fails, do not increment i
                } else {
                    uint256 gasRebate = (gasBefore - gasleft()) * GAS_REBATE_MULTIPLIER_BPS / BPS_DENOMINATOR;
                    if (balance < gasRebate) gasRebate = balance; // ensure gas rebate does not exceed balance

                    totalGasRebate += gasRebate;
                    s_symbiontBalances[symbiont] = balance - gasRebate;
                    i++; // finally increment i
                }
            }
        }

        // credit recipient with claim, could just send directly but has potential security implications
        if (totalGasRebate > 0) {
            s_poolManager.mint(recipient, 0, totalGasRebate);
            s_poolManager.sync(CurrencyLibrary.ADDRESS_ZERO);
            s_poolManager.settle{value: totalGasRebate}();
        }
    }
}
