// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKey, PoolIdLibrary} from "v4-core/types/PoolId.sol";

type Receptor is bytes32;

library ReceptorLibrary {
    using PoolIdLibrary for PoolKey;

    function from(PoolKey memory key, bytes4 selector) internal pure returns (Receptor) {
        return Receptor.wrap(keccak256(abi.encodePacked(key.toId(), selector)));
    }
}
