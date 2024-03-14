# NftGuessr Smart Contract

## Overview

- [NFTGuessr](https://nftguessr.com)
- [WhitePaper](https://nftguessr.gitbook.io/white-paper/)

NFTGuessr is a game similar to GeoGuessr.  
The idea is to find the location represented by NFT of a Google Street View.  
This game operates on the EVM (Zama). Each location is associated with an NFT GeoSpace (GSP) encrypted with FHE. To
inquire if the found location is correct (if is within the 5 km² radius of the NFT location), it costs you 1 Zama (base
fee).  
If you have found it, you win the NFT and 2 ERC20 SpaceCoin (SPC).

Four options are available to you:

- 💼 just hold your GeoSpace in your wallet.
- 🎁 Re-engage your GeoSpace in game with a winning tax (ZAMA). Also, unlock the right to create other NFTs for the game
  and you can earn SpaceCoin.
- 🔓 Stake SpaceCoin to earn Zama when a player makes a guess request.

## Games explain description

### Smart contract NFTGuessr

The smart contract has a fixed tax ZAMA (1 token by default) and a radius (5 km² by default). The contract owner can
change this values and withdraw fees. When an NFT is held by a user, it is not possible for another user to find the
NFT. If a user puts their NFT back into play, **they will not be able to win it**. If a user is the creator of an NFT,
they can **NEVER** win that NFT.

### Token management

- A total of 50 million SpaceCoin tokens are created. They are allocated among the team (10%) and the users (80%), with
  a portion reserved (10%). The distribution is carried out using the game.
- 1 SPC is minted when player guess and distribute with all creators of GeoSpace (the creators must call claimReward). 1
  SPC is created when a player win a NFT. 1 SPC is burn when a player create a NFT.

### Fees management

- Guess fees: 2 Zama => 1 for teams, and 1 distribute with all staker of SpaceCoin.
- Win fees: a creator or player can set a winning tax. If the player wins, then the prize money will be distributed to
  the previous owner, and 3% will go to the creator of the NFT.

### Staker SPC

The spaceCoin staker will receive Zama tokens when a player makes a guess.

### Back in game

An NFT holder can put their NFT back into play with a winning tax. With this action the player can create other NFT for
the game. Limited by lifePoint creation.

### Check Gps

A user sends an NFT ID along with latitude and longitude (without decimal (1e15)), and a **MINIMUM** of 2 token + NFT
winning fees to verify if their location is within a 5 km² radius of the specified NFT ID. If it is, the NFT is
transferred to the user; otherwise, nothing happens.

### Create Gps

If the user has access to NFT creation, they must have a valid location, meaning with a latitude and longitude and
others with conversion (without decimal (1e15)) for which a Google Street View is available. **It's cost 1 SPC**. => is
burn

## Table of Contents

0. [Libraries](#libraries)
1. [Structs](#structs)
2. [Modifiers](#modifiers)
3. [Owner Functions](#owner-functions)
4. [Fallback Functions](#fallback-functions)
5. [Getter Functions](#getter-functions)
6. [Changer Functions](#changer-functions)
7. [Internal Functions](#internal-functions)
8. [Internal Functions Utils](#internal-functions-utils)
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

### 0.6 ERC20

External library for ERC20

```solidity
"@openzeppelin/contracts/token/ERC20/ERC20.sol";
```

## 1. Structs <a name="structs"></a>

### 1.1 Location

Represents the encrypted geographical coordinates of an NFT location.

```solidity
struct Location {
  euint64 northLat;
  euint64 southLat;
  euint64 eastLon;
  euint64 westLon;
  euint64 lat;
  euint64 lng;
  bool isValid;
}
```

### 1.2 NFTLocation`

Represents the decrypted geographical coordinates of an NFT location.

```solidity
struct NFTLocation {
  uint64 northLat;
  uint64 southLat;
  uint64 eastLon;
  uint64 westLon;
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

Allows the owner to withdraw Zama from the contract.

```solidity
function withdraw() external onlyOwner {
  // ... (Withdraw functionality)
}
```

### 3.2 withdrawToken

Allows the owner to withdraw token SPC from the contract.

```solidity
function withdrawToken() external onlyOwner {
  // ... (Withdraw token functionality)
}
```

### 3.3 rewardUsersWithERC20

Function to reward the user with ERC-20 tokens script launch every 24 hours and check if user have receive reward in a
same day.

```solidity
function rewardUsersWithERC20() external onlyOwner {
  // ... (reward and transfer functionality)
}
```

## 4. Fallback Functions <a name="fallback-functions"></a>

### 4.1 receive

Fallback function to receive Ether.

```solidity
receive() external payable {}
```

## 5. Getter Functions <a name="getter-functions"></a>

### 5.4 getNFTLocation

Gets the location of an NFT for the contract owner.

```solidity
function getNFTLocation(uint256 tokenId) external view onlyOwner returns (NFTLocation memory) {
  // ... (Get NFT location for owner)
}
```

### 5.5 getNFTLocationForOwner

Gets the location of an NFT for the owner.

```solidity
function getNFTLocationForOwner(uint256 tokenId) external view returns (NFTLocation memory) {
  // ... (Get NFT location for owner)
}
```

### 5.6 getAddressResetWithToken

Gets the address associated with the reset of an NFT.

```solidity
function getAddressResetWithToken(uint256 _tokenId) public view returns (address) {
  // ... (Get address associated with NFT reset)
}
```

### 5.7 getAddressCreationWithToken

Gets the address associated with the creation of an NFT.

```solidity
function getAddressCreationWithToken(uint256 _tokenId) public view returns (address) {
  // ... (Get address associated with NFT creation)
}
```

### 5.8 getAddressStakeWithToken

Gets the address associated with the staking of an NFT.

```solidity
function getAddressStakeWithToken(uint256 _tokenId) public view returns (address) {
  // ... (Get address associated with NFT staking)
}
```

### 5.9 getFee

Gets the fee associated with a user and an NFT.

```solidity
function getFee(address user, uint256 id) external view returns (uint256) {
  // ... (Get fee associated with user and NFT)
}
```

### 5.10 getOwnedNFTs

Gets an array of NFTs owned by a user.

```solidity
function getOwnedNFTs(address user) external view returns (uint256[] memory) {
  // ... (Get array of owned NFTs)
}
```

### 5.11 getNftCreationAndFeesByUser

Gets the creation IDs and fees of NFTs created by a user.

```solidity
function getNftCreationAndFeesByUser(address user) public view returns (uint256[] memory, uint256[] memory) {
  // ... (Get NFT creation IDs and fees by user)
}
```

### 5.12 getResetNFTsAndFeesByOwner

Gets the IDs and fees of NFTs reset by a user.

```solidity
function getResetNFTsAndFeesByOwner(address user) public view returns (uint256[] memory, uint256[] memory) {
  // ... (Get reset NFT IDs and fees by owner)
}
```

### 5.13 getNFTsStakedByOwner

Gets the IDs of NFTs staked by a user.

```solidity
function getNFTsStakedByOwner(address _owner) public view returns (uint256[] memory) {
  // ... (Get NFT IDs staked by owner)
}
```

### 5.14 getNFTsResetByOwner

Gets the IDs of NFTs reset by a user.

```solidity
function getNFTsResetByOwner(address _owner) public view returns (uint256[] memory) {
  // ... (Get NFT IDs reset by owner)
}
```

### 5.15 getTotalNft

Gets the total number of NFTs in existence.

```solidity
function getTotalNft() public view returns (uint256) {
  // ... (Get total number of NFTs)
}
```

### 5.16 isLocationValid

Check if the location is valid. (true or false) stake, own or not.

```solidity
function isLocationValid(uint256 locationId) public view returns (bool) {
  // ... (Check if location is valid functionality)
}
```

### 5.17 isAccessCreation

Check if user have access to creation gps (3 NFT GeoSpace stake).

```solidity
function isAccessCreation(address user) public view returns (bool) {
  // ... (Check if location access functionality)
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

### 6.4 setAddressToken

Change address tokenERC20.

```solidity
function setAddressToken(address _tokenErc20) external onlyOwner {
  // ... (Setter functionality)
}
```

### 6.5 changeFeesCreation

Function to change the fees required for NFT creation.

```solidity
function changeFeesCreation(uint256 _feesCreation) external onlyOwner {
  // ... (Change fees)
}
```

### 6.6 changeRewardUser

Function to change reward user checkGps in SPC

```solidity
function changeRewardUser(uint256 _amountReward) external onlyOwner {
  // ... (Change reward)
}
```

### 6.7 changeRewardUsers

Function to change reward user daily 24h in SPC

```solidity
function changeRewardUsers(uint256 _amountReward) external onlyOwner {
  // ... (Change reward)
}
```

### 6.8 changeAmountMintErc20

    // Function to change amount mint with function createGpsOwnerNft

```solidity
function changeAmountMintErc20(uint256 _amountMintErc20) external onlyOwner {
  // ... (Change reward)
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

1. Check if `data.length` is good.
2. Loop through the `data` array.
3. Increment counter `tokenId`
4. Create struct `Location` with encrypted value. (`euint64`).
5. Check if location exist on smart contract with `isLocationAlreadyUsed`.
6. If ok, `locate` is save on `locations`.
7. Set mapping `userFees` with `msg.sender`.
8. Set mapping `isStake` to false.
9. Set mapping `creatorNft` save `msg.sender` with `tokenId`.
10. Set mapping `tokenCreationAddress` to save `msg.sender` and `tokenId` to access facilitate (no loop for).
11. Set mapping `ownerNft` to prevent owner indirectly.
12. call function `_mint` of oppenZepplin.
13. Emit event.

```solidity
function mint(bytes[] calldata data, address _owner, uint256[] calldata feesData) internal {
  // ... (Mint NFTs functionality)
}
```

### 7.6 rewardUserWithERC20

Function to transfer reward the user if stake minimum 1 NFT GeoSpace with ERC-20 tokens SpaceCoin

```solidity
function rewardUserWithERC20(address user) internal view returns (bool) {
  // ... (transfer user reward)
}
```

### 7.7 createObjectLocation

Function internal to create object Location with conversion FHE bytes to euint

```solidity
function createObjectLocation(bytes[] calldata data, uint256 baseIndex) internal pure returns (Location memory) {
  // ... (create object Location)
}
```

### 7.8 setDataForMinting

Function to set data mapping and array for minting NFT GeoSpace function

```solidity
function setDataForMinting(uint256 tokenId, uint256 feesToSet, Location memory locate) internal {
  // ... (set data on variables)
}
```

## 8. Internal Functions Utils <a name="internal-functions-utils"></a>

### 8.1 resetMapping

Internal function to reset mappings.

```solidity
function resetMapping(uint256 tokenId, address previous) internal {
  // ... (Reset mapping functionality)
}
```

### 8.2 removeElement

Internal function to remove an element from an array uint256.

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
function isOnPoint(euint64 lat, euint64 lng, Location memory location) internal view returns (bool) {
  // ... (Check if coordinates are within location functionality)
}
```

### 8.5 removeElementAdress

Internal function to remove an element from an array address.

```solidity
function removeElementAddress(address[] storage array, address element) internal {
  // ... (Remove element from array functionality)
}
```

### 8.6 containsAddress

     Internal function to check if an element exists in an array.

```solidity
function containsAddress(address[] storage array, address element) internal view returns (bool) {
  // ... (return bool if success)
}
```

### 8.7 transactionCoinSpace

Internal function to create transaction from msg.sender to smart contract

```solidity
function transactionCoinSpace() internal {
  // ... (transfer erc20 to smart contract)
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
9. Check if `ownerNft` is owner, because the smart contract can hold an NFT owned by a user, as is the case with Staking
   or back in game of the NFT.
10. Check if `msg.sender` is the creator of nft.
11. Check fees (fees base + fees creator or back in game).
12. Transfer fund to smart contract and user owner correspondly fees.
13. Delete all mapping (fees, valid location true to false)
14. Transfer `ownerNft` to `msg.sender`
15. Transfer NFT to winner.
16. Emit event.

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

### 9.8 burnNFT

Function to burn (destroy) an NFT.

```solidity
function burnNFT(uint256 tokenId) external onlyOwner {
  // ... (Burn NFT functionality)
}
```

## 10. Conclusion <a name="conclusion"></a>

The NftGuessr smart contract provides a flexible and secure platform for a location-based NFT guessing game. Users can
create, stake, transfer, reset, and interact with NFTs using encrypted GPS coordinates. The contract ensures ownership,
fee management, and location validation while emitting events to track key activities.

### Author

[Jérémy Combe]

### License

This contract is licensed under the MIT License.
