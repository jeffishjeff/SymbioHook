// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.27;

import {Currency} from "v4-core/types/Currency.sol";

library Reserves {
    // bytes32(uint256(keccak256("Reserves")) + 1)
    bytes32 constant RESERVES_SLOT = 0xa3f4358a852d3bf06359f3160e18e93cb34f7c5445671784e027b47b0510bf6b;

    function sync(Currency currency0, uint256 reserve0, Currency currency1, uint256 reserve1) internal {
        assembly ("memory-safe") {
            switch currency0
            case 0 {
                tstore(RESERVES_SLOT, 0)
                tstore(add(RESERVES_SLOT, 0x20), 0)
            }
            default {
                tstore(RESERVES_SLOT, and(currency0, 0xffffffffffffffffffffffffffffffffffffffff))
                tstore(add(RESERVES_SLOT, 0x20), reserve0)
            }

            tstore(add(RESERVES_SLOT, 0x40), and(currency1, 0xffffffffffffffffffffffffffffffffffffffff))
            tstore(add(RESERVES_SLOT, 0x60), reserve1)
        }
    }

    function get() internal view returns (Currency currency0, uint256 reserve0, Currency currency1, uint256 reserve1) {
        assembly ("memory-safe") {
            currency0 := tload(RESERVES_SLOT)
            reserve0 := tload(add(RESERVES_SLOT, 0x20))
            currency1 := tload(add(RESERVES_SLOT, 0x40))
            reserve1 := tload(add(RESERVES_SLOT, 0x60))
        }
    }
}
