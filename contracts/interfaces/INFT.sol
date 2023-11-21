// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "fhevm/lib/TFHE.sol";

interface INFT {
    struct Location {
        euint32 northLat;
        euint32 southLat;
        euint32 eastLon;
        euint32 westLon;
        euint32 lat;
        euint32 lng;
    }

    struct NFTLocation {
        uint32 northLat;
        uint32 southLat;
        uint32 eastLon;
        uint32 westLon;
        uint tax;
        uint lat;
        uint lng;
    }

    struct NFT {
        address owner;
        Location location;
        bool claimed;
        uint256 tokenId; // Ajout de l'identifiant unique
        bool isStaked;
        bool isReset;
        uint256 tax;
        address creator;
    }
}
