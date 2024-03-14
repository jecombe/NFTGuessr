// Structs.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "fhevm/lib/TFHE.sol";

struct NFTLocation {
    bytes lat;
    bytes lng;
}

struct Location {
    euint64 northLat;
    euint64 southLat;
    euint64 eastLon;
    euint64 westLon;
    euint64 lat;
    euint64 lng;
    bool isValid;
}
