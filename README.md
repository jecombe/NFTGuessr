# NftGuessr Smart Contract

## Overview

- [NFTGuessr](http://nftguessr.com)
- [Medium](https://medium.com/@jeremcombe/nftguessr-6dcfde3621ac)

NFTGuessr is a game similar to GeoGuessr. The idea is to find the location of a Google Street View. This game operates
on the EVM (Zama). Each location is associated with an NFT encrypted with FHE. To inquire if the found location is
correct (if is within the 5km2 radius of the NFT location), it costs you 1 Zama (base fee). If you have found it, you
win the NFT. Two options are available to you:

- Either you put the NFT back into play with your tax for one round.
- Accumulate 3 NFTs to stake them, unlocking the right to create NFTs with GPS coordinates, including your tax for one
  round.

### Author

[Jérémy Combe]

### License

This contract is licensed under the MIT License.

## Table of Contents

0. [Libraries](#libraries)
1. [Structs](#structs)
2. [Modifiers](#modifiers)
3. [Owner Functions](#owner-functions)
4. [Fallback Functions](#fallback-functions)
5. [Getter Functions](#getter-functions)
6. [Changer Functions](#changer-functions)
7. [Internal Functions](#internal-functions)
8. [Internal Functions Utiles](#internal-functions-utiles)
9. [Gaming Functions](#gaming-functions)
10. [Conclusion](#conclusion)

## 0. Libraries <a name="libraries"></a>

### 0.1 TFHE

External library for handling encrypted operations

```solidity
import "fhevm/lib/TFHE.sol";
```

### 0.2 Counter

Provided by OpenZeppelin, used for managing token IDs.

```solidity
import "@openzeppelin/contracts/utils/Counters.sol";
```

### 0.3 Ownable

Provided by OpenZepplin, used for manage ownable of smart contract.

```solidity
import "@openzeppelin/contracts/access/Ownable.sol";
```

### 0.4 Safe Math

Provided by OppenZepplin, used for math.

```solidity
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
```

### 0.5 ERC721Enumerable

An extension of the ERC721 standard, allowing enumeration of all tokens.

```solidity
"@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

```

## 1. Structs <a name="structs"></a>

### 1.1 Location

Represents the encrypted geographical coordinates of an NFT location.

```solidity
struct Location {
  euint32 northLat;
  euint32 southLat;
  euint32 eastLon;
  euint32 westLon;
  euint32 lat;
  euint32 lng;
  bool isValid;
}
```

### 1.2 NFTLocation`

Represents the decrypted geographical coordinates of an NFT location.

```solidity
struct NFTLocation {
  uint32 northLat;
  uint32 southLat;
  uint32 eastLon;
  uint32 westLon;
  uint lat;
  uint lng;
}
```

## 2. Modifiers <a name="modifiers"></a>

### 2.1 isAccess

Checks if the user has access to certain functionalities.

```solidity
modifier isAccess() {
    require(stakeNft[msg.sender].length >= 3, "The owner must stake 3 NFTs to create a new NFT");
    _;
}

```

## 3. Owner Functions <a name="owner-functions"></a>

### 3.1 withdraw

Allows the owner to withdraw Ether from the contract.

```solidity
function withdraw() external onlyOwner {
  // ... (Withdraw functionality)
}
```

## 4. Fallback Functions <a name="fallback-functions"></a>

### 4.1 receive

Fallback function to receive Ether.

```solidity
receive() external payable {}
```

## 5. Getter Functions <a name="getter-functions"></a>

### 5.1 getNbStake

Gets the number of NFTs required to stake.

```solidity
function getNbStake() external view returns (uint256) {
  // ... (Get number of NFTs required to stake)
}
```

### 5.2 getTotalStakedNFTs

Gets the total number of staked NFTs.

```solidity
function getTotalStakedNFTs() external view returns (uint256) {
  // ... (Get total number of staked NFTs)
}
```

### 5.3 getNFTLocation

Gets the location of an NFT for the contract owner.

```solidity
function getNFTLocation(uint256 tokenId) external view onlyOwner returns (NFTLocation memory) {
  // ... (Get NFT location for owner)
}
```

### 5.4 getNFTLocationForOwner

Gets the location of an NFT for the owner.

```solidity
function getNFTLocationForOwner(uint256 tokenId) external view returns (NFTLocation memory) {
  // ... (Get NFT location for owner)
}
```

### 5.5 getAddressResetWithToken

Gets the address associated with the reset of an NFT.

```solidity
function getAddressResetWithToken(uint256 _tokenId) public view returns (address) {
  // ... (Get address associated with NFT reset)
}
```

### 5.6 getAddressCreationWithToken

Gets the address associated with the creation of an NFT.

```solidity
function getAddressCreationWithToken(uint256 _tokenId) public view returns (address) {
  // ... (Get address associated with NFT creation)
}
```

### 5.7 getAddressStakeWithToken

Gets the address associated with the staking of an NFT.

```solidity
function getAddressStakeWithToken(uint256 _tokenId) public view returns (address) {
  // ... (Get address associated with NFT staking)
}
```

### 5.8 getFee

Gets the fee associated with a user and an NFT.

```solidity
function getFee(address user, uint256 id) external view returns (uint256) {
  // ... (Get fee associated with user and NFT)
}
```

### 5.9 getOwnedNFTs

Gets an array of NFTs owned by a user.

```solidity
function getOwnedNFTs(address user) external view returns (uint256[] memory) {
  // ... (Get array of owned NFTs)
}
```

### 5.10 getNftCreationAndFeesByUser

Gets the creation IDs and fees of NFTs created by a user.

```solidity
function getNftCreationAndFeesByUser(address user) public view returns (uint256[] memory, uint256[] memory) {
  // ... (Get NFT creation IDs and fees by user)
}
```

### 5.11 getResetNFTsAndFeesByOwner

Gets the IDs and fees of NFTs reset by a user.

```solidity
function getResetNFTsAndFeesByOwner(address user) public view returns (uint256[] memory, uint256[] memory) {
  // ... (Get reset NFT IDs and fees by owner)
}
```

### 5.12 getNFTsStakedByOwner

Gets the IDs of NFTs staked by a user.

```solidity
function getNFTsStakedByOwner(address _owner) public view returns (uint256[] memory) {
  // ... (Get NFT IDs staked by owner)
}
```

### 5.13 getNFTsResetByOwner

Gets the IDs of NFTs reset by a user.

```solidity
function getNFTsResetByOwner(address _owner) public view returns (uint256[] memory) {
  // ... (Get NFT IDs reset by owner)
}
```

### 5.14 getTotalNft

Gets the total number of NFTs in existence.

```solidity
function getTotalNft() public view returns (uint256) {
  // ... (Get total number of NFTs)
}
```

## 6. Changer Functions <a name="changer-functions"></a>

### 6.1 changeFees

Changes the fees required for NFT operations.

```solidity
function changeFees(uint256 _fees) external onlyOwner {
  // ... (Change fees functionality)
}
```

### 6.2 changeNbNftStake

Changes the number of NFTs required to stake.

```solidity
function changeNbNftStake(uint256 _nb) external onlyOwner {
  // ... (Change number of NFTs required to stake functionality)
}
```

### 6.3 changeOwner

Changes the owner of the contract.

```solidity
function changeOwner(address _newOwner) external onlyOwner {
  // ... (Change owner functionality)
}
```

## 7. Internal Functions <a name="internal-functions"></a>

### 7.1 \_baseURI

Internal function to return the base URI for metadata.

```solidity
function _baseURI() internal view virtual override(ERC721) returns (string memory) {
  // ... (Get base URI for metadata)
}
```

### 7.2 getLocation

Internal function to get the decrypted location.

- Return struct `Location`.
- Use `TFHE.decrypt` to decrypt location.

```solidity
function getLocation(Location memory _location) internal view returns (NFTLocation memory) {
  // ... (Get decrypted location)
}
```

### 7.3 isLocationAlreadyUsed

Internal function to check if the location is already used.

- Return true if location doesn't exist on smart contract
- Use `TFHE.optReq` to require if `TFHE.ne` value compare between location send by creator and smart contract

```solidity
function isLocationAlreadyUsed(Location memory newLocation) internal view {
  // ... (Check if location is already used)
}
```

### 7.4 checkFees

Internal function to check if the user has enough funds to pay NFT tax.

```solidity
function checkFees(uint256 _tokenId, address previous) internal view returns (uint256) {
  // ... (Check user fees functionality)
}
```

### 7.5 mint

Internal function to mint NFTs with location data and associated fees.

1. Cehck if `data.length` is good.
2. Loop through the `data` array.
3. Increment counter `tokenId`
4. Create struct `Location` with encrypted value. (`euint32`).
5. Check if location exist on smart contract with `isLocationAlreadyUsed`.
6. If ok, `locate` is save on `locations`.
7. Set mapping `userFees` with `msg.sender`.
8. Set mapping `isStake` to false.
9. Set mapping `creatorNft` save `msg.sender` with `tokenId`.
10. Set mapping `tokenCreationAddress` to save `msg.sender` and `tokenId` to access facilitate (no loop for).
11. Set mapping `previousOwner` to prevent owner indirectly.
12. call function `_mint` of oppenZepplin.
13. Emit event.

```solidity
function mint(bytes[] calldata data, address _owner, uint256[] calldata feesData) internal {
  // ... (Mint NFTs functionality)
}
```

## 8. Internal Functions Utiles <a name="internal-functions-utiles"></a>

### 8.1 resetMapping

Internal function to reset mappings.

```solidity
function resetMapping(uint256 tokenId, address previous) internal {
  // ... (Reset mapping functionality)
}
```

### 8.2 removeElement

Internal function to remove an element from an array.

```solidity
function removeElement(uint256[] storage array, uint256 element) internal {
  // ... (Remove element from array functionality)
}
```

### 8.3 contains

Internal function to check if an element exists in an array.

```solidity
function contains(uint256[] storage array, uint256 element) internal view returns (bool) {
  // ... (Check if element exists in array functionality)
}
```

### 8.4 isOnPoint

Internal function to check if a set of coordinates is within a location.

- Return true latitude and longitude is arround 5km2 else return false
- Use `TFHE.ge` to check if latitude and longitude is gretter or equal and `TFHE.le` inverse.
- Use `TFHE.decrypt` to decrypt boolean and use it on function checkGps check if location is good.

```solidity
function isOnPoint(euint32 lat, euint32 lng, Location memory location) internal view returns (bool) {
  // ... (Check if coordinates are within location functionality)
}
```

### 8.5 burnNFT

Internal function to burn (destroy) an NFT.

```solidity
function burnNFT(uint256 tokenId) external onlyOwner {
  // ... (Burn NFT functionality)
}
```

### 8.6 isLocationValid

Internal function to check if the location is valid.

```solidity
function isLocationValid(uint256 locationId) public view returns (bool) {
  // ... (Check if location is valid functionality)
}
```

## 9. Gaming Functions <a name="gaming-functions"></a>

### 9.1 createGpsOwner

Creates one or more NFTs with taxes only for the owner smart contract (tax set on 0)

```solidity
function createGpsOwner(bytes[] calldata data, uint256[] calldata feesData) external onlyOwner {
  // ... (Create NFTs functionality for owner)
}
```

### 9.2 createGpsOwnerNft

Creates one or more NFTs with taxes (for one round only) for the owner of the NFT.

```solidity
function createGpsOwnerNft(bytes[] calldata data, uint256[] calldata feesData) external isAccess {
  // ... (Create NFTs functionality for owner of the NFT)
}
```

### 9.3 stakeNFT

Stakes one or more NFTs

```solidity
function stakeNFT(uint256[] calldata nftIndices) external {
  // ... (Stake NFTs functionality)
}
```

### 9.4 unstakeNFT

Unstakes one or more NFTs, deleting taxes.

```solidity
function unstakeNFT(uint256[] calldata nftIndices) external {
  // ... (Unstake NFTs functionality)
}
```

### 9.5 checkGps

Checks GPS coordinates against a specified location's coordinates. This function allows determining whether a user finds
the NFT located within a 5km² radius of the latitude and longitude of the GPS point.

1. Decrypt value send by `msg.sender`.
2. Get `totalSupply` to check if `nftId` send by `msg.sender` is lower than `totalSupply`.
3. Check if `locations[_tokenId]` is valid (if variable boolean `isValid` set on `true`).
4. Check if latitude (`lat`) and longitude (`lng`) send by `msg.sender` is `onPoint` (check part Functions internals
   8.4).
5. Check if `msg.sender` is the `ownerOf(_tokenId)`.
6. Before the function check if location is valid to check (if other user have nft).
7. The creator of nft cannot win.
8. To prevent, stake nft id cannot win (but check before (3)).
9. Check if `previousOwner` is owner, because the smart contract can hold an NFT owned by a user, as is the case with
   Staking or back in game of the NFT.
10. Check fees (fees base + fees creator or back in game).
11. Transfer fund to smart contract and user correspondly fees.
12. Delete all mapping (fees, valid location true to false)
13. Transfer `previousOwner` to `msg.sender`
14. Transfer NFT to winner.
15. Emit event.

```solidity
function checkGps(
  bytes calldata userLatitude,
  bytes calldata userLongitude,
  uint256 _tokenId
) external payable returns (bool) {
  // ... (Check GPS functionality)
}
```

### 9.6 resetNFT

Resets one or more NFTs, putting them back into the game with tax just for one round

```solidity
function resetNFT(uint256[] calldata tokenIds, uint256[] calldata taxes) external {
  // ... (Reset NFTs functionality)
}
```

### 9.7 resetNFT

Cancels the reset of one or more NFTs.

```solidity
function cancelResetNFT(uint256[] calldata tokenIds) external {
  // ... (Cancel reset of NFTs functionality)
}
```

## 10. Conclusion <a name="conclusion"></a>

The NftGuessr smart contract provides a flexible and secure platform for a location-based NFT guessing game. Users can
create, stake, transfer, reset, and interact with NFTs using encrypted GPS coordinates. The contract ensures ownership,
fee management, and location validation while emitting events to track key activities.
