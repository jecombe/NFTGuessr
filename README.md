# NftGuessr - Smart Contract Documentation

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

## Contract Structure

### Libraries Used

- TFHE Library: External library for handling encrypted operations.
- Counters Library: Provided by OpenZeppelin, used for managing token IDs.

### Contract Inheritance

- ERC721Enumerable: An extension of the ERC721 standard, allowing enumeration of all tokens.

### State Variables

#### Token Counters:

- `_tokenIdCounter`: Counter for generating unique token IDs.

#### Base Token URI:

- `_baseTokenURI`: Base URI for metadata of NFTs.

#### Location Parameters:

- `nbNftStake`: Number of NFTs required to stake.
- `stakedNFTCount`: Total number of staked NFTs.
- `resetNFTCount`: Total number of reset NFTs.

#### Structs:

- `NFTLocation`: Structure to store the location of an NFT.
- `Location`: Structure to store location information with encrypted coordinates.

#### Fees and Ownership:

- `fees`: Fee required for NFT operations.
- `owner`: Address of the contract owner.

#### Mappings:

- `locations`: Mapping to store NFT locations.
- `locationsNonAccessible`: Mapping to store non-accessible locations during a reset.
- Other mappings for tracking NFT creators, stake, reset, fees, and ownership.

#### Events:

- `GpsCheckResult`: Event emitted when a user checks GPS coordinates against an NFT location.
- `createNFT`: Event emitted when a new NFT is created.
- `ResetNFT`: Event emitted when an NFT is reset.

#### Constructor:

- Initializes the contract with the name "GeoSpace" and symbol "GSP," sets the base token URI, and defines the contract
  owner.

#### Modifiers:

- `onlyOwner`: Modifier to restrict access to the owner only.

#### Fallback Function:

- `receive`: Fallback function to receive Ether.

## External Functions

### Metadata and URI Functions

- `_baseURI`: Internal function to return the base URI for metadata.

### Ownership and Administrative Functions

- `changeOwner`: Change the owner of the contract.
- `changeFees`: Change the fees required for NFT operations.
- `changeNbNftStake`: Change the number of NFTs required to stake.

### Token Interaction Functions

- `transferNFT`: Transfer an NFT to another address.
- `getTotalStakedNFTs`: Get the total number of staked NFTs.

### Location and Token Information Functions

- `getNFTLocation`: Get the location of an NFT using decrypted coordinates.
- `getAddressResetWithToken`: Get the address associated with the reset of an NFT.
- `getAddressStakeWithToken`: Get the address associated with the staking of an NFT.
- `getFee`: Get the fee associated with a user and an NFT.
- `getOwnedNFTs`: Get an array of NFTs owned by a user.
- `getNftCreationAndFeesByUser`: Get the creation IDs and fees of NFTs created by a user.
- `getNFTsAndFeesByOwner`: Get the IDs and fees of NFTs owned by a user.
- `getResetNFTsAndFeesByOwner`: Get the IDs and fees of NFTs reset by a user.
- `getNFTsStakedByOwner`: Get the IDs of NFTs staked by a user.
- `getNFTsResetByOwner`: Get the IDs of NFTs reset by a user.
- `getTotalNft`: Get the total number of NFTs in existence.
- `getNbStake`: Get the number of NFTs required to stake.

### GPS Check Functions

- `checkGps`: Check GPS coordinates against a specified location's coordinates. This function checks if a request is
  within a 5km² radius of the GPS location of the NFT. If yes, then a transfer is executed to send the NFT to the
  msg.sender
- `isLocationValid`: Check if a location is valid.

### NFT Stake and Reset Functions

- `stakeNFT`: Stake NFTs by the sender.
- `unstakeNFT`: Unstake NFTs by the sender.
- `resetNFT`: Reset one or more NFTs, putting them back into the game.
- `cancelResetNFT`: Cancel the reset of one or more NFTs.

### NFT Creation Functions

- `createGpsOwner`: Create NFTs owned by the contract owner with given location data.
- `createGpsOwnerNft`: Create NFTs owned by the sender with given location data.

## Internal Functions

- `mint`: Internal function to mint NFTs with location data and associated fees.
- `removeElement`: Internal function to remove an element from an array.
- `contains`: Internal function to check if an element exists in an array.
- `isOnPoint`: Internal function to check if given coordinates are within a location.
- `resetMapping`: Internal function to reset mapping.

## Conclusion

The NftGuessr smart contract provides a flexible and secure platform for a location-based NFT guessing game. Users can
create, stake, transfer, reset, and interact with NFTs using encrypted GPS coordinates. The contract ensures ownership,
fee management, and location validation while emitting events to track key activities.
