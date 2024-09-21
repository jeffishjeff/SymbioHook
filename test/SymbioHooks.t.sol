// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks, IHooks} from "v4-core/libraries/Hooks.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Deployers} from "../lib/v4-core/test/utils/Deployers.sol";
import {DampenedOracleSymbiontHook} from "../src/DampenedOracleSymbiontHook.sol";
import {DoubleGasRebateHostHook} from "../src/DoubleGasRebateHostHook.sol";

contract SymbioHooks is Test, Deployers {
    DoubleGasRebateHostHook hostHook;
    DampenedOracleSymbiontHook symbiontHook;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        address hostHookAddress = address(
            uint160(
                Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                    | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_DONATE_FLAG
            )
        );
        deployCodeTo("DoubleGasRebateHostHook.sol", abi.encode(manager), hostHookAddress);
        hostHook = DoubleGasRebateHostHook(hostHookAddress);

        (key,) = initPoolAndAddLiquidity(currency0, currency1, hostHook, 3000, SQRT_PRICE_1_1, ZERO_BYTES);

        address symbiontHookAddress = address(uint160(Hooks.AFTER_SWAP_FLAG));
        deployCodeTo("DampenedOracleSymbiontHook.sol", abi.encode(hostHook), symbiontHookAddress);
        symbiontHook = DampenedOracleSymbiontHook(symbiontHookAddress);
    }

    function test_symbiontCanAttachToHost() public {
        _attach();

        IHooks[] memory symbionts = hostHook.symbionts(key, symbiontHook.afterSwap.selector);
        assertEq(symbionts.length, 1);
        assertEq(address(symbionts[0]), address(symbiontHook));
    }

    function test_symbiontCanDetachFromHost() public {
        _attach();
        _detach();

        IHooks[] memory symbionts = hostHook.symbionts(key, symbiontHook.afterSwap.selector);
        assertEq(symbionts.length, 0);
    }

    function test_symbiontCanRefillUnattached() public {
        assertEq(hostHook.balanceOf(symbiontHook), 0 ether);

        symbiontHook.refill{value: 1 ether}();
        assertEq(hostHook.balanceOf(symbiontHook), 1 ether);

        symbiontHook.refill{value: 2 ether}();
        assertEq(hostHook.balanceOf(symbiontHook), 3 ether);
    }

    function test_symbiontCanRefillAttached() public {
        _attach();

        assertEq(hostHook.balanceOf(symbiontHook), 0 ether);

        symbiontHook.refill{value: 1 ether}();
        assertEq(hostHook.balanceOf(symbiontHook), 1 ether);

        symbiontHook.refill{value: 2 ether}();
        assertEq(hostHook.balanceOf(symbiontHook), 3 ether);
    }

    function test_symbiontIsUnaffectedByUnattachedHookCalls() public {
        _attach();
        symbiontHook.refill{value: 1 ether}();

        // add liquidity
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
        assertEq(hostHook.balanceOf(symbiontHook), 1 ether);

        // remove liquidity
        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);
        assertEq(hostHook.balanceOf(symbiontHook), 1 ether);

        // donate
        donateRouter.donate(key, 1 ether, 1 ether, ZERO_BYTES);
        assertEq(hostHook.balanceOf(symbiontHook), 1 ether);
    }

    function test_symbiontIsAffectedByAttachedHookCalls() public {
        _attach();
        symbiontHook.refill{value: 1 ether}();

        assertEq(hostHook.balanceOf(symbiontHook), 1 ether);
        assertEq(symbiontHook.consult(key), 0);

        // swap
        swapRouter.swap(
            key, SWAP_PARAMS, PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}), ZERO_BYTES
        );
        assertNotEq(hostHook.balanceOf(symbiontHook), 1 ether);
        assertNotEq(symbiontHook.consult(key), 0);
    }

    function test_symbiontGetsDetachedIfInsufficientBalance() public {
        _attach();

        IHooks[] memory symbionts = hostHook.symbionts(key, symbiontHook.afterSwap.selector);
        assertEq(symbionts.length, 1);
        assertEq(address(symbionts[0]), address(symbiontHook));

        // swap
        swapRouter.swap(
            key, SWAP_PARAMS, PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}), ZERO_BYTES
        );

        symbionts = hostHook.symbionts(key, symbiontHook.afterSwap.selector);
        assertEq(symbionts.length, 0);
    }

    function _attach() private {
        PoolKey[] memory keys = new PoolKey[](1);
        keys[0] = key;
        symbiontHook.attach(keys);
    }

    function _detach() private {
        PoolKey[] memory keys = new PoolKey[](1);
        keys[0] = key;
        symbiontHook.detach(keys);
    }
}
