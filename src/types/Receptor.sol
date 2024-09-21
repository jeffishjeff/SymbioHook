// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {PoolKey} from "v4-core/types/PoolKey.sol";

type Receptor is bytes32;

using ReceptorLibrary for Receptor global;

library ReceptorLibrary {
    function from(PoolKey memory key, bytes4 selector) internal pure returns (Receptor) {
        return Receptor.wrap(keccak256(abi.encode(key, selector)));
    }
}
