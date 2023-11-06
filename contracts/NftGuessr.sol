// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "fhevm/lib/TFHE.sol";

contract NftGuessr {
    string public name = "GeoSpace"; // Ajout du nom de la collection
    string public symbol = "GSP"; // Ajout du symbole de la collection
    uint256 public nextTokenId = 0; // Compteur d'identifiants uniques

    struct Location {
        euint32 northLat;
        euint32 southLat;
        euint32 eastLon;
        euint32 westLon;
    }

    struct NFT {
        address owner;
        Location location;
        bool claimed;
        uint256 tokenId; // Ajout de l'identifiant unique
    }
    uint256 public fees;
    address public owner;
    NFT[] public nfts;

    constructor() {
        owner = msg.sender;
        fees = 1 ether;
    }

    event GpsCheckResult(address indexed user, bool result);
    event NFTTransfer(address indexed from, address indexed to, uint256 tokenId);
    event NFTReset(uint256 indexed tokenId, address indexed owner);
    event NFTTransferred(uint256 indexed tokenId, address indexed from, address indexed to);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can perform this action");
        _;
    }

    receive() external payable {
        // Cette fonction permet de recevoir des ethers
    }

    function getNFTOwnersAndTokenIds() public view returns (address[] memory, uint256[] memory) {
        address[] memory owners = new address[](nfts.length);
        uint256[] memory tokenIds = new uint256[](nfts.length);

        for (uint256 i = 0; i < nfts.length; i++) {
            owners[i] = nfts[i].owner;
            tokenIds[i] = nfts[i].tokenId;
        }

        return (owners, tokenIds);
    }

    function resetNFT(uint256 nftIndex) public onlyOwner {
        require(nftIndex < nfts.length, "Invalid NFT index");
        address previousOwner = nfts[nftIndex].owner;
        nfts[nftIndex].owner = address(0); // Reset to address(0) to indicate not claimed
        nfts[nftIndex].claimed = false;
        emit NFTReset(nfts[nftIndex].tokenId, previousOwner);
    }

    function transferNFT(address to, uint256 nftIndex) public {
        require(nftIndex < nfts.length, "Invalid NFT index");
        require(msg.sender == nfts[nftIndex].owner, "You are not the owner of this NFT");
        address previousOwner = nfts[nftIndex].owner;
        nfts[nftIndex].owner = to;
        nfts[nftIndex].claimed = false;
        emit NFTTransferred(nfts[nftIndex].tokenId, previousOwner, to);
    }

    function createNFT(
        bytes[] calldata _northLat,
        bytes[] calldata _southLat,
        bytes[] calldata _eastLon,
        bytes[] calldata _westLon
    ) public onlyOwner {
        for (uint256 i = 0; i < _southLat.length; i++) {
            euint32 northLat = TFHE.asEuint32(_northLat[i]);
            euint32 southLat = TFHE.asEuint32(_southLat[i]);
            euint32 eastLon = TFHE.asEuint32(_eastLon[i]);
            euint32 westLon = TFHE.asEuint32(_westLon[i]);

            Location memory location = Location(northLat, southLat, eastLon, westLon);
            NFT memory newNFT = NFT(msg.sender, location, false, nextTokenId);
            nfts.push(newNFT);
            nextTokenId++;
        }
    }

    function withdraw() public onlyOwner {
        address payable payableOwner = payable(owner);
        payableOwner.transfer(address(this).balance);
    }

    function changeFees(uint256 _fees) public onlyOwner {
        fees = _fees * 1 ether;
    }

    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    // Fonction pour obtenir le nom de la collection
    function getName() public view returns (string memory) {
        return name;
    }

    // Fonction pour obtenir le symbole de la collection
    function getSymbol() public view returns (string memory) {
        return symbol;
    }

    function checkGps(bytes calldata userLatitude, bytes calldata userLongitude) public payable returns (bool) {
        require(
            msg.value >= fees,
            string(abi.encodePacked("Frais insuffisants. Un minimum de ", fees, " MATIC est requis."))
        );

        euint32 lat = TFHE.asEuint32(userLatitude);
        euint32 lng = TFHE.asEuint32(userLongitude);
        bool result = false;

        for (uint256 i = 0; i < nfts.length; i++) {
            require(msg.sender != nfts[i].owner, "You cannot claim your own NFT");
            bool isGreaterLat = TFHE.decrypt(TFHE.ge(lat, nfts[i].location.southLat));

            bool isLessLat = TFHE.decrypt(TFHE.le(lat, nfts[i].location.northLat));
            bool isGreaterLng = TFHE.decrypt(TFHE.ge(lng, nfts[i].location.westLon));
            bool isLessLng = TFHE.decrypt(TFHE.le(lng, nfts[i].location.eastLon));

            if (!nfts[i].claimed && isGreaterLat && isLessLat && isGreaterLng && isLessLng) {
                require(!nfts[i].claimed, "Another person own NFT");
                result = true;
                address previousOwner = nfts[i].owner;
                nfts[i].owner = msg.sender;
                nfts[i].claimed = true;
                emit NFTTransfer(previousOwner, msg.sender, nfts[i].tokenId);
                break;
            }
        }

        // Émettez l'événement pour indiquer le résultat
        emit GpsCheckResult(msg.sender, result);

        return result;
    }

    function getNFTOwner(uint256 nftIndex) public view returns (address) {
        require(nftIndex < nfts.length, "Invalid NFT index");
        return nfts[nftIndex].owner;
    }
}
