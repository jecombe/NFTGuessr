// Structs.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "fhevm/lib/TFHE.sol";

struct NFTLocation {
    bytes lat;
    bytes lng;
}

struct Location {
    euint32 northLat;
    euint32 southLat;
    euint32 eastLon;
    euint32 westLon;
    euint32 lat;
    euint32 lng;
    bool isValid;
}

struct LastError {
    euint8 error;
    uint timestamp;
}
