// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import "../structs/StructsNftGuessr.sol";
import "../erc20/SpaceCoin.sol";
import "../airdrop/AirDrop.sol";
import "../erc721/GeoSpace.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "fhevm/lib/TFHE.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "fhevm/abstracts/EIP712WithModifier.sol";

library Lib {
    // Internal function to check if user in on nft radius.

    // Internal function to remove an element from an array uint.
    function removeElement(uint[] storage array, uint element) internal {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == element) {
                array[i] = array[array.length - 1];
                array.pop();
                return;
            }
        }
    }

    // Internal function to check if an element exists in an array.
    function contains(uint[] storage array, uint element) internal view returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return true;
            }
        }
        return false;
    }

    // Internal function to create object Location with conversion FHE bytes to euint
    function createObjectLocation(bytes[] calldata data, uint baseIndex) internal pure returns (Location memory) {
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
