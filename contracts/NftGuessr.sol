pragma solidity ^0.8.19;
import "fhevm/lib/TFHE.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NftGuessr is ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    string private _baseTokenURI;

    uint256 public nbNftStake = 3;
    uint256 public stakedNFTCount = 0;
    uint256 public resetNFTCount = 0;

    struct Location {
        euint32 northLat;
        euint32 southLat;
        euint32 eastLon;
        euint32 westLon;
        euint32 lat;
        euint32 lng;
        bool isValid;
    }

    uint256 public fees = 1 ether;
    address public owner;

    mapping(uint256 => Location) internal locations;
    mapping(uint256 => Location) internal locationsNonAccessible;

    mapping(address => uint256[]) public creatorNft;
    mapping(address => mapping(uint256 => uint256)) public userFees;
    mapping(uint256 => address) previousOwner;
    mapping(address => uint256[]) public stakeNft;
    mapping(address => uint256[]) public resetNft;

    event GpsCheckResult(address indexed user, bool result, uint256 tokenId);
    event createNFT(address indexed user, uint256 tokenId, uint256 fee);
    event ResetNFT(address indexed user, uint256 tokenId, bool isReset);

    constructor() ERC721("GeoSpace", "GSP") {
        _baseTokenURI = "";
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    receive() external payable {}

    // Fonction pour transférer un NFT à un autre utilisateur
    function transferNFT(address to, uint256 tokenId) public {
        // Ajouter une vérification pour s'assurer que le NFT n'est pas staké
        require(!contains(stakeNft[msg.sender], tokenId), "Cannot transfer a staked NFT");
        require(!contains(resetNft[msg.sender], tokenId), "Cannot transfer a reset NFT");

        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not authorized to transfer");
        locationsNonAccessible[tokenId] = locations[tokenId];
        delete locations[tokenId];
        _transfer(_msgSender(), to, tokenId);
    }

    function getTotalStakedNFTs() public view returns (uint256) {
        return stakedNFTCount;
    }

    // Fonction pour récupérer les frais pour un ID spécifique pour une adresse donnée
    function getFee(address user, uint256 id) external view returns (uint256) {
        return userFees[user][id];
    }

    // Fonction pour brûler (burn) un NFT
    function burnNFT(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }

    function getOwnedNFTs(address user) public view returns (uint256[] memory) {
        uint256[] memory ownedNFTs = new uint256[](balanceOf(user));

        for (uint256 i = 0; i < balanceOf(user); i++) {
            ownedNFTs[i] = tokenOfOwnerByIndex(user, i);
        }

        return ownedNFTs;
    }

    function getNftCreationAndFeesByUser(address user) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory ids = new uint256[](creatorNft[user].length);
        uint256[] memory feesNft = new uint256[](creatorNft[user].length);

        for (uint256 i = 0; i < creatorNft[user].length; i++) {
            uint256 tokenId = creatorNft[user][i];
            ids[i] = tokenId;
            feesNft[i] = userFees[user][tokenId];
        }

        return (ids, feesNft);
    }

    function getNFTsAndFeesByOwner(address user) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory ownedNFTs = getOwnedNFTs(user);
        uint256[] memory nftFees = new uint256[](ownedNFTs.length);

        for (uint256 i = 0; i < ownedNFTs.length; i++) {
            uint256 tokenId = ownedNFTs[i];
            nftFees[i] = userFees[user][tokenId];
        }

        return (ownedNFTs, nftFees);
    }

    function getResetNFTsAndFeesByOwner(address user) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory resetNFTs = resetNft[user];
        uint256[] memory nftFees = new uint256[](resetNFTs.length);

        for (uint256 i = 0; i < resetNFTs.length; i++) {
            uint256 tokenId = resetNFTs[i];
            nftFees[i] = userFees[user][tokenId];
        }

        return (resetNFTs, nftFees);
    }

    function getNFTsStakedByOwner(address _owner) public view returns (uint256[] memory) {
        return stakeNft[_owner];
    }

    function getNFTsResetByOwner(address _owner) public view returns (uint256[] memory) {
        return resetNft[_owner];
    }

    function getTotalNft() public view returns (uint256) {
        return totalSupply();
    }

    function changeFees(uint256 _fees) public onlyOwner {
        fees = _fees * 1 ether;
    }

    function getNbStake() public view returns (uint256) {
        return nbNftStake;
    }

    function changeNbNftStake(uint256 _nb) public onlyOwner {
        nbNftStake = _nb;
    }

    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    function _baseURI() internal view virtual override(ERC721) returns (string memory) {
        return _baseTokenURI;
    }

    function createGpsOwner(bytes[] calldata data) public onlyOwner {
        mint(data, address(this));
    }

    function createGpsOwnerNft(bytes[] calldata data) public {
        require(stakeNft[msg.sender].length >= 3, "The owner must stake 3 NFTs to create a new NFT");

        mint(data, address(this));
    }

    function mint(bytes[] calldata data, address _owner) internal {
        require(data.length >= 7, "Insufficient data provided");

        uint256 arrayLength = data.length / 7;

        for (uint256 i = 0; i < arrayLength; i++) {
            uint256 baseIndex = i * 7;

            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();

            // Créer une instance de Location associée au tokenId
            locations[tokenId] = Location({
                northLat: TFHE.asEuint32(data[baseIndex]),
                southLat: TFHE.asEuint32(data[baseIndex + 1]),
                eastLon: TFHE.asEuint32(data[baseIndex + 2]),
                westLon: TFHE.asEuint32(data[baseIndex + 3]),
                lat: TFHE.asEuint32(data[baseIndex + 4]),
                lng: TFHE.asEuint32(data[baseIndex + 5]),
                isValid: true
            });
            _mint(_owner, tokenId);
            uint256 fee = TFHE.decrypt(TFHE.asEuint32(data[baseIndex + 6]));
            userFees[msg.sender][tokenId] = fee;

            // Mettre à jour la mapping stakeNft
            creatorNft[_owner].push(tokenId);
            previousOwner[tokenId] = _owner;
            emit createNFT(_owner, tokenId, fee);
        }
    }

    function stakeNFT(uint256[] calldata nftIndices) public {
        require(nftIndices.length > 0, "No NFTs to stake");

        for (uint256 i = 0; i < nftIndices.length; i++) {
            uint256 nftId = nftIndices[i];

            require(ownerOf(nftId) == msg.sender);
            require(!contains(stakeNft[msg.sender], nftId));

            stakeNft[msg.sender].push(nftId);
            stakedNFTCount++;
        }
    }

    function unstakeNFT(uint256[] calldata nftIndices) public {
        require(nftIndices.length > 0, "No NFTs to unstake");

        for (uint256 i = 0; i < nftIndices.length; i++) {
            uint256 nftId = nftIndices[i];

            require(ownerOf(nftId) == msg.sender);
            require(contains(stakeNft[msg.sender], nftId));

            // Retirer l'ID du NFT du tableau stakeNft
            removeElement(stakeNft[msg.sender], nftId);
            stakedNFTCount--;
        }
    }

    // Fonction utilitaire pour retirer un élément d'un tableau
    function removeElement(uint256[] storage array, uint256 element) internal {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                // Déplacer le dernier élément à la place de l'élément à retirer
                array[i] = array[array.length - 1];
                // Réduire la longueur du tableau
                array.pop();
                return;
            }
        }
    }

    // Fonction utilitaire pour vérifier si un élément est présent dans un tableau
    function contains(uint256[] storage array, uint256 element) internal view returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return true;
            }
        }
        return false;
    }

    function reenecryptLocation(Location memory location, bytes32 publicKey) internal view returns (bytes[6] memory) {
        return [
            TFHE.reencrypt(location.northLat, publicKey),
            TFHE.reencrypt(location.southLat, publicKey),
            TFHE.reencrypt(location.eastLon, publicKey),
            TFHE.reencrypt(location.westLon, publicKey),
            TFHE.reencrypt(location.lat, publicKey),
            TFHE.reencrypt(location.lng, publicKey)
        ];
    }

    function getLocation(uint256 tokenId, bytes32 publicKey) public view onlyOwner returns (bytes[6] memory) {
        Location memory location = locations[tokenId];
        return reenecryptLocation(location, publicKey);
    }

    function getLocationNonAccessible(
        uint256 tokenId,
        bytes32 publicKey
    ) public view onlyOwner returns (bytes[6] memory) {
        Location memory location = locationsNonAccessible[tokenId];
        return reenecryptLocation(location, publicKey);
    }

    function isOnPoint(euint32 lat, euint32 lng, Location memory location) internal view returns (bool) {
        return (TFHE.decrypt(TFHE.ge(lat, location.southLat)) &&
            TFHE.decrypt(TFHE.le(lat, location.northLat)) &&
            TFHE.decrypt(TFHE.ge(lng, location.westLon)) &&
            TFHE.decrypt(TFHE.le(lng, location.eastLon)));
    }

    function isLocationValid(uint256 locationId) public view returns (bool) {
        return locations[locationId].isValid;
    }

    function checkGps(
        bytes calldata userLatitude,
        bytes calldata userLongitude,
        uint256 _tokenId
    ) public payable returns (bool) {
        require(
            msg.value >= fees,
            string(abi.encodePacked("Insufficient fees. A minimum of ", fees, " MATIC is required."))
        );
        euint32 lat = TFHE.asEuint32(userLatitude);
        euint32 lng = TFHE.asEuint32(userLongitude);

        bool result = false;
        uint256 totalSupply = totalSupply();

        require(_tokenId <= totalSupply);
        require(isLocationValid(_tokenId), "Location does not exist");

        Location memory location = locations[_tokenId];

        if (isOnPoint(lat, lng, location)) {
            require(ownerOf(_tokenId) != msg.sender);

            address previous = previousOwner[_tokenId];
            uint256 nftFees = userFees[previous][_tokenId];
            uint256 totalTax = fees + nftFees;

            require(msg.value >= totalTax, "Insufficient funds to pay NFT tax");

            payable(previous).transfer(nftFees);
            locationsNonAccessible[_tokenId] = locations[_tokenId];

            delete userFees[previous][_tokenId];
            delete locations[_tokenId];
            delete previousOwner[_tokenId];
            delete creatorNft[previous];

            _transfer(ownerOf(_tokenId), msg.sender, _tokenId);
            removeElement(resetNft[previous], _tokenId);
            previousOwner[_tokenId] = msg.sender;
            result = true;
        }
        emit GpsCheckResult(msg.sender, result, _tokenId);
        return result;
    }

    function resetNFT(uint256[] calldata tokenIds, uint256[] calldata taxes) public {
        require(tokenIds.length > 0, "No token IDs provided");
        require(tokenIds.length == taxes.length, "Invalid input lengths");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 tax = taxes[i];
            require(ownerOf(tokenId) == msg.sender, "You can only put your own NFT in the game");
            require(!contains(stakeNft[msg.sender], tokenId), "NFT is staked, please unstake before");

            if (!contains(resetNft[msg.sender], tokenId)) {
                userFees[msg.sender][tokenId] = tax;
                resetNft[msg.sender].push(tokenId);
                previousOwner[tokenId] = ownerOf(tokenId);
                locations[tokenId] = locationsNonAccessible[tokenId];
                _transfer(msg.sender, address(this), tokenId);
                delete locationsNonAccessible[tokenId];
                emit ResetNFT(msg.sender, tokenId, true);
            }
        }
    }

    function cancelResetNFT(uint256[] calldata tokenIds) public {
        require(tokenIds.length > 0, "No token IDs provided");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            if (contains(resetNft[msg.sender], tokenId)) {
                _transfer(address(this), msg.sender, tokenId);
                locationsNonAccessible[tokenId] = locations[tokenId];
                delete locations[tokenId];
                userFees[msg.sender][tokenId] = 0;
                removeElement(resetNft[msg.sender], tokenId);
                emit ResetNFT(msg.sender, tokenId, false);
            }
        }
    }
}
