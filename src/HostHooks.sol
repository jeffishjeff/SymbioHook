// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.27;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {ParseBytes} from "v4-core/libraries/ParseBytes.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IHostHooks} from "./interfaces/IHostHooks.sol";
import {ISymbiontHooks} from "./interfaces/ISymbiontHooks.sol";
import {Receptor, ReceptorLibrary} from "./types/Receptor.sol";

contract HostHooks is IHostHooks {
    using Hooks for IHooks;
    using ParseBytes for bytes;

    error HookNotImplemented();

    uint256 private constant GAS_LIMIT_BPS = 100;
    uint256 private constant GAS_REBATE_MULTIPLIER_BPS = 15_000;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    IPoolManager private immutable s_poolManager;
    mapping(Receptor => ISymbiontHooks[]) private s_receptorSymbionts;
    mapping(ISymbiontHooks => uint256) private s_symbiontBalances;

    constructor(IPoolManager poolManager) {
        s_poolManager = poolManager;
    }

    /// @inheritdoc IHostHooks
    function attach(PoolKey calldata key, bytes4[] calldata selectors) external {
        for (uint256 i = 0; i < selectors.length; i++) {
            s_receptorSymbionts[ReceptorLibrary.from(key, selectors[i])].push(ISymbiontHooks(msg.sender));
        }
    }

    /// @inheritdoc IHostHooks
    function detach(PoolKey calldata key, bytes4[] calldata selectors) external {
        for (uint256 i = 0; i < selectors.length; i++) {
            _detach(ReceptorLibrary.from(key, selectors[i]), ISymbiontHooks(msg.sender));
        }
    }

    /// @inheritdoc IHostHooks
    function refill() external payable {
        s_symbiontBalances[ISymbiontHooks(msg.sender)] += msg.value;
    }

    /// @inheritdoc IHooks
    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        // TODO:
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        // TODO:
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function afterAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external virtual returns (bytes4, BalanceDelta) {
        // TODO:
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external virtual returns (bytes4, BalanceDelta) {
        // TODO:
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external virtual returns (bytes4, int128) {
        Receptor receptor = ReceptorLibrary.from(key, this.afterSwap.selector);
        ISymbiontHooks[] storage s_symbionts = s_receptorSymbionts[receptor];

        uint256 totalGasRebat;
        for (uint256 i = 0; i < s_symbionts.length;) {
            ISymbiontHooks symbiont = s_symbionts[i];
            uint256 gasLimit = (block.gaslimit * GAS_LIMIT_BPS) / BPS_DENOMINATOR;

            if (s_symbiontBalances[symbiont] < gasLimit) {
                _detach(receptor, symbiont);
            } else {
                uint256 gasBefore = gasleft();
                (bool success, bytes memory result) = _callSymbiont(
                    symbiont, abi.encodeCall(IHooks.afterSwap, (sender, key, params, delta, hookData)), gasLimit
                );

                if (!success) {
                    _detach(receptor, symbiont);
                } else {
                    uint256 gasRebate = (gasBefore - gasleft()) * GAS_REBATE_MULTIPLIER_BPS / BPS_DENOMINATOR;
                    if (s_symbiontBalances[symbiont] < gasRebate) {
                        gasRebate = s_symbiontBalances[symbiont];
                    }

                    totalGasRebat += gasRebate;
                    s_symbiontBalances[symbiont] -= gasRebate;
                    i++;
                }
            }
        }

        if (totalGasRebat > 0) {
            s_poolManager.mint(sender, 0, totalGasRebat);
            s_poolManager.sync(CurrencyLibrary.ADDRESS_ZERO);
            s_poolManager.settleFor{value: totalGasRebat}(sender);
        }
    }

    /// @inheritdoc IHooks
    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        // TODO:
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function beforeInitialize(address, PoolKey calldata, uint160, bytes calldata) external virtual returns (bytes4) {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function afterInitialize(address, PoolKey calldata, uint160, int24, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        external
        virtual
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    /// @notice Helper function to detach a symbiont from a receptor
    function _detach(Receptor receptor, ISymbiontHooks symbiont) private {
        ISymbiontHooks[] storage s_symbionts = s_receptorSymbionts[receptor];

        for (uint256 i = 0; i < s_symbionts.length; i++) {
            if (s_symbionts[i] == symbiont) {
                s_symbionts[i] = s_symbionts[s_symbionts.length - 1];
                s_symbionts.pop();
                return;
            }
        }
    }

    /// @notice Helper function to call symbiont, does not re-throw
    function _callSymbiont(ISymbiontHooks symbiont, bytes memory data, uint256 gasLimit)
        private
        returns (bool success, bytes memory result)
    {
        assembly ("memory-safe") {
            success := call(gasLimit, symbiont, 0, add(data, 0x20), mload(data), 0, 0)
        }

        if (success) {
            assembly ("memory-safe") {
                result := mload(0x40)
                mstore(0x40, add(result, and(add(returndatasize(), 0x3f), not(0x1f))))
                mstore(result, returndatasize())
                returndatacopy(add(result, 0x20), 0, returndatasize())
            }

            success = result.length >= 32 && result.parseSelector() != data.parseSelector();
        }
    }
}
