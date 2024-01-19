// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import "../structs/StructsNftGuessr.sol";
import "../erc20/Erc20.sol";
import "../airdrop/AirDrop.sol";
import "../Game.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "fhevm/lib/TFHE.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "fhevm/abstracts/EIP712WithModifier.sol";

library Lib {
    // Définissez vos fonctions de bibliothèque ici
    // Internal function to check if user in on nft radius.
    function isOnPoint(euint32 lat, euint32 lng, Location memory location) internal view returns (bool) {
        ebool isLatSouth = TFHE.ge(lat, location.southLat); //if lat >= location.southLat => true if correct
        ebool isLatNorth = TFHE.le(lat, location.northLat); // if lat <= location.northLat => true if correct
        ebool isLatValid = TFHE.and(isLatSouth, isLatNorth);

        ebool isLngWest = TFHE.ge(lng, location.westLon); // true if correct
        ebool isLngEast = TFHE.le(lng, location.eastLon); // true if correct
        ebool isLngValid = TFHE.and(isLngWest, isLngEast);

        return TFHE.decrypt(TFHE.and(isLngValid, isLatValid)); // Check if lat AND long are valid
    }

    // Internal function to remove an element from an array uint256.
    function removeElement(uint256[] storage array, uint256 element) internal {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                array[i] = array[array.length - 1];
                array.pop();
                return;
            }
        }
    }

    // Internal function to check if an element exists in an array.
    function contains(uint256[] storage array, uint256 element) internal view returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return true;
            }
        }
        return false;
    }

    // Internal function to create object Location with conversion FHE bytes to euint
    function createObjectLocation(bytes[] calldata data, uint256 baseIndex) internal pure returns (Location memory) {
        return
            Location({
                northLat: TFHE.asEuint32(data[baseIndex]),
                southLat: TFHE.asEuint32(data[baseIndex + 1]),
                eastLon: TFHE.asEuint32(data[baseIndex + 2]),
                westLon: TFHE.asEuint32(data[baseIndex + 3]),
                lat: TFHE.asEuint32(data[baseIndex + 4]),
                lng: TFHE.asEuint32(data[baseIndex + 5]),
                isValid: true
            });
    }
}
