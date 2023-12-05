// Structs.sol
pragma solidity ^0.8.19;

import "fhevm/lib/TFHE.sol";

struct NFTLocation {
    uint32 northLat;
    uint32 southLat;
    uint32 eastLon;
    uint32 westLon;
    uint lat;
    uint lng;
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
