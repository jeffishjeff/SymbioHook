// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

/// @notice Interface for HostHooks
interface IHostHooks {
    /// @notice Attaches msg.sender as a symbiont to specified functions of the pool
    function attach(PoolKey calldata key, bytes4[] calldata selectors) external;

    /// @notice Detaches msg.sender as a symbiont from specified functions of the pool
    function detach(PoolKey calldata key, bytes4[] calldata selectors) external;

    /// @notice Refills the gas balance of the symbiont
    function refill() external payable;

    /// @notice Returns the pool manager
    function poolManager() external view returns (IPoolManager);

    /// @notice Returns the attached symbionts of the pool's function
    function symbionts(PoolKey calldata key, bytes4 selector) external view returns (IHooks[] memory);

    /// @notice Returns the gas balance of the symbiont
    function balanceOf(IHooks symbiont) external view returns (uint256);
}
