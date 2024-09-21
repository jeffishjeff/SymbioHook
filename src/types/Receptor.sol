// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKey, PoolIdLibrary} from "v4-core/types/PoolId.sol";

/// @notice Receptor identifies the (pool, function) pair that a symbiont is attached to
type Receptor is bytes32;

library ReceptorLibrary {
    using PoolIdLibrary for PoolKey;

    /// @notice Identify the receptor for the specified (pool, function) pair
    function from(PoolKey memory key, bytes4 selector) internal pure returns (Receptor) {
        return Receptor.wrap(keccak256(abi.encodePacked(key.toId(), selector)));
    }
}
