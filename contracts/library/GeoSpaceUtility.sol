// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../interfaces/INFT.sol";

library GeoSpaceUtility {
    function removeNFTFromOwner(
        mapping(address => uint256[]) storage nftsByOwner,
        address _owner,
        uint256 _tokenId
    ) internal {
        uint256[] storage ownerNFTs = nftsByOwner[_owner];
        for (uint256 i = 0; i < ownerNFTs.length; i++) {
            if (ownerNFTs[i] == _tokenId) {
                if (i != ownerNFTs.length - 1) {
                    ownerNFTs[i] = ownerNFTs[ownerNFTs.length - 1];
                }
                ownerNFTs.pop();
                break;
            }
        }
    }

    function removeNftStakeFromOwner(
        mapping(address => uint256[]) storage stakedNFTsByOwner,
        address _owner,
        uint256 _tokenId
    ) internal {
        uint256[] storage ownerNFTs = stakedNFTsByOwner[_owner];
        for (uint256 i = 0; i < ownerNFTs.length; i++) {
            if (ownerNFTs[i] == _tokenId) {
                if (i != ownerNFTs.length - 1) {
                    ownerNFTs[i] = ownerNFTs[ownerNFTs.length - 1];
                }
                ownerNFTs.pop();
                break;
            }
        }
    }

    function removeNftResetFromOwner(
        mapping(address => uint256[]) storage resetNFTsByOwner,
        address _owner,
        uint256 _tokenId
    ) internal {
        uint256[] storage ownerNFTs = resetNFTsByOwner[_owner];
        for (uint256 i = 0; i < ownerNFTs.length; i++) {
            if (ownerNFTs[i] == _tokenId) {
                if (i != ownerNFTs.length - 1) {
                    ownerNFTs[i] = ownerNFTs[ownerNFTs.length - 1];
                }
                ownerNFTs.pop();
                break;
            }
        }
    }

    //GETTER
    function getNFTOwnersAndTokenIds(
        INFT.NFT[] calldata nfts
    ) internal pure returns (address[] memory, uint256[] memory) {
        address[] memory owners = new address[](nfts.length);
        uint256[] memory tokenIds = new uint256[](nfts.length);

        for (uint256 i = 0; i < nfts.length; i++) {
            owners[i] = nfts[i].owner;
            tokenIds[i] = nfts[i].tokenId;
        }

        return (owners, tokenIds);
    }

    function setTax(INFT.NFT[] memory nfts, uint256 tokenId, uint256 newTax) internal view {
        require(msg.sender == nfts[tokenId - 1].owner, "You can only set tax for your own NFT");
        require(!nfts[tokenId - 1].isReset, "NFT is reset");
        require(!nfts[tokenId - 1].isStaked, "NFT is staked");

        nfts[tokenId - 1].tax = newTax;
    }

    function changeNFTTax(INFT.NFT[] memory nfts, uint256 tokenId, uint256 newTax) public view {
        require(msg.sender == nfts[tokenId - 1].owner, "You can only change tax for your own NFT");
        require(nfts[tokenId - 1].isReset, "NFT is not reset");
        require(!nfts[tokenId - 1].isStaked, "NFT is staked");

        nfts[tokenId - 1].tax = newTax;
    }

    function getNFTLocation(
        INFT.NFT[] memory nfts,
        uint256 tokenId,
        uint256 nextTokenId
    ) internal view returns (INFT.NFTLocation memory) {
        require(tokenId >= 1 && tokenId < nextTokenId, "Invalid NFT token ID");

        uint256 nftIndex = tokenId - 1;
        require(nftIndex < nfts.length, "Invalid NFT index");

        INFT.Location memory location = nfts[nftIndex].location;
        uint32 northLat = TFHE.decrypt(location.northLat);
        uint32 southLat = TFHE.decrypt(location.southLat);
        uint32 eastLon = TFHE.decrypt(location.eastLon);
        uint32 westLon = TFHE.decrypt(location.westLon);
        uint tax = nfts[nftIndex].tax;
        uint lat = TFHE.decrypt(location.lat);
        uint lng = TFHE.decrypt(location.lng);

        INFT.NFTLocation memory nftLocation = INFT.NFTLocation(northLat, southLat, eastLon, westLon, tax, lat, lng);
        return nftLocation;
    }

    function getNFTLocationOwner(
        INFT.NFT[] memory nfts,
        uint256 tokenId,
        uint256 nextTokenId
    ) internal view returns (INFT.NFTLocation memory) {
        require(tokenId >= 1 && tokenId < nextTokenId, "Invalid NFT token ID");

        uint256 nftIndex = tokenId - 1; // Soustrayez 1 pour l'index correct
        require(nftIndex < nfts.length, "Invalid NFT index");
        require(msg.sender == nfts[nftIndex].owner, "you are not the owner of GeoSpace");

        INFT.Location memory location = nfts[nftIndex].location;
        uint32 northLat = TFHE.decrypt(location.northLat);
        uint32 southLat = TFHE.decrypt(location.southLat);
        uint32 eastLon = TFHE.decrypt(location.eastLon);
        uint32 westLon = TFHE.decrypt(location.westLon);
        uint tax = nfts[nftIndex].tax;
        uint lat = TFHE.decrypt(location.lat);
        uint lng = TFHE.decrypt(location.lng);

        INFT.NFTLocation memory nftLocation = INFT.NFTLocation(northLat, southLat, eastLon, westLon, tax, lat, lng);
        return nftLocation;
    }

    function createNFT(
        bytes[] calldata data,
        uint256 nextTokenId,
        address owner,
        INFT.NFT[] memory nfts
    ) internal pure {
        uint256 arrayLength = data.length / 7;

        for (uint256 i = 0; i < arrayLength; i++) {
            uint256 baseIndex = i * 7;

            euint32 northLat = TFHE.asEuint32(data[baseIndex]);
            euint32 southLat = TFHE.asEuint32(data[baseIndex + 1]);
            euint32 eastLon = TFHE.asEuint32(data[baseIndex + 2]);
            euint32 westLon = TFHE.asEuint32(data[baseIndex + 3]);
            euint32 lat = TFHE.asEuint32(data[baseIndex + 4]);
            euint32 lng = TFHE.asEuint32(data[baseIndex + 5]);

            INFT.Location memory location = INFT.Location(northLat, southLat, eastLon, westLon, lat, lng);
            nfts[i] = INFT.NFT(owner, location, false, nextTokenId, false, false, 0, owner);
        }
    }
}
