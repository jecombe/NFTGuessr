// @title NftGuessr - Smart contract for a location-based NFT guessing game.
// @author [Jérémy Combe]
// @notice This contract extends ERC721Enumerable for NFT functionality.

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

    // Struct to store the location of an NFT.
    struct NFTLocation {
        uint32 northLat;
        uint32 southLat;
        uint32 eastLon;
        uint32 westLon;
        uint lat;
        uint lng;
    }

    // Struct to store location information with encrypted coordinates.
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

    // Mapping to store NFT locations and non-accessible locations.
    mapping(uint256 => Location) internal locations;
    mapping(uint256 => Location) internal locationsNonAccessible;

    // Mapping to track NFT creators / stake / reset and their fees.
    mapping(address => uint256[]) public creatorNft;
    mapping(address => mapping(uint256 => uint256)) public userFees;
    mapping(uint256 => address) previousOwner;
    mapping(address => uint256[]) public stakeNft;
    mapping(uint256 => bool) public isStake;
    mapping(uint256 => address) public tokenStakeAddress;
    mapping(uint256 => address) public tokenResetAddress;
    mapping(address => uint256[]) public resetNft;

    // Event emitted when a user checks the GPS coordinates against an NFT location.
    event GpsCheckResult(address indexed user, bool result, uint256 tokenId);

    // Event emitted when a new NFT is created.
    event createNFT(address indexed user, uint256 tokenId, uint256 fee);

    // Event emitted when an NFT is reset.
    event ResetNFT(address indexed user, uint256 tokenId, bool isReset);

    // Contract constructor initializes base token URI and owner.
    constructor() ERC721("GeoSpace", "GSP") {
        _baseTokenURI = "";
        owner = msg.sender;
    }

    // Modifier to restrict access to the owner only.
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // Fallback function to receive Ether.
    receive() external payable {}

    // Function to transfer an NFT to another address.
    function transferNFT(address to, uint256 tokenId) public {
        require(!contains(stakeNft[msg.sender], tokenId), "Cannot transfer a staked NFT");
        require(!contains(resetNft[msg.sender], tokenId), "Cannot transfer a reset NFT");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not authorized to transfer");

        locationsNonAccessible[tokenId] = locations[tokenId];
        delete locations[tokenId];
        _transfer(_msgSender(), to, tokenId);
    }

    // Function to get the total number of staked NFTs.
    function getTotalStakedNFTs() public view returns (uint256) {
        return stakedNFTCount;
    }

    // Function to get the location of an NFT using decrypted coordinates.
    function getNFTLocation(uint256 tokenId) public view onlyOwner returns (NFTLocation memory) {
        Location memory location = locations[tokenId];
        uint32 northLat = TFHE.decrypt(location.northLat);
        uint32 southLat = TFHE.decrypt(location.southLat);
        uint32 eastLon = TFHE.decrypt(location.eastLon);
        uint32 westLon = TFHE.decrypt(location.westLon);
        uint lat = TFHE.decrypt(location.lat);
        uint lng = TFHE.decrypt(location.lng);
        NFTLocation memory nftLocation = NFTLocation(northLat, southLat, eastLon, westLon, lat, lng);
        return nftLocation;
    }

    // Function to get the address associated with the reset of an NFT.
    function getAddressResetWithToken(uint256 _tokenId) public view returns (address) {
        return tokenResetAddress[_tokenId];
    }

    // Function to get the address associated with the staking of an NFT.
    function getAddressStakeWithToken(uint256 _tokenId) public view returns (address) {
        return tokenStakeAddress[_tokenId];
    }

    // Function to get the fee associated with a user and an NFT.
    function getFee(address user, uint256 id) external view returns (uint256) {
        return userFees[user][id];
    }

    // Function to burn (destroy) an NFT, only callable by the owner.
    function burnNFT(uint256 tokenId) public onlyOwner {
        address previous = previousOwner[tokenId];

        delete userFees[previous][tokenId];
        delete isStake[tokenId];
        delete locations[tokenId];
        delete previousOwner[tokenId];
        delete creatorNft[previous];

        _burn(tokenId);
    }

    // Function to get an array of NFTs owned by a user.
    function getOwnedNFTs(address user) public view returns (uint256[] memory) {
        uint256[] memory ownedNFTs = new uint256[](balanceOf(user));

        for (uint256 i = 0; i < balanceOf(user); i++) {
            ownedNFTs[i] = tokenOfOwnerByIndex(user, i);
        }

        return ownedNFTs;
    }

    // Function to get the creation IDs and fees of NFTs created by a user.
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

    // Function to get the IDs and fees of NFTs owned by a user.
    function getNFTsAndFeesByOwner(address user) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory ownedNFTs = getOwnedNFTs(user);
        uint256[] memory nftFees = new uint256[](ownedNFTs.length);

        for (uint256 i = 0; i < ownedNFTs.length; i++) {
            uint256 tokenId = ownedNFTs[i];
            nftFees[i] = userFees[user][tokenId];
        }

        return (ownedNFTs, nftFees);
    }

    // Function to get the IDs and fees of NFTs reset by a user.
    function getResetNFTsAndFeesByOwner(address user) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory resetNFTs = resetNft[user];
        uint256[] memory nftFees = new uint256[](resetNFTs.length);

        for (uint256 i = 0; i < resetNFTs.length; i++) {
            uint256 tokenId = resetNFTs[i];
            nftFees[i] = userFees[user][tokenId];
        }

        return (resetNFTs, nftFees);
    }

    // Function to get the IDs of NFTs staked by a user.
    function getNFTsStakedByOwner(address _owner) public view returns (uint256[] memory) {
        return stakeNft[_owner];
    }

    // Function to get the IDs of NFTs reset by a user.
    function getNFTsResetByOwner(address _owner) public view returns (uint256[] memory) {
        return resetNft[_owner];
    }

    // Function to get the total number of NFTs in existence.
    function getTotalNft() public view returns (uint256) {
        return totalSupply();
    }

    // Function to change the fees required for NFT operations.
    function changeFees(uint256 _fees) public onlyOwner {
        fees = _fees * 1 ether;
    }

    // Function to get the number of NFTs required to stake.
    function getNbStake() public view returns (uint256) {
        return nbNftStake;
    }

    // Function to change the number of NFTs required to stake.
    function changeNbNftStake(uint256 _nb) public onlyOwner {
        nbNftStake = _nb;
    }

    // Function to change the owner of the contract.
    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    // Internal function to return the base URI for metadata.
    function _baseURI() internal view virtual override(ERC721) returns (string memory) {
        return _baseTokenURI;
    }

    // Function to create NFTs owned by the contract owner with given location data.
    function createGpsOwner(bytes[] calldata data) public onlyOwner {
        mint(data, address(this));
    }

    // Function to create NFTs owned by the sender with given location data.
    function createGpsOwnerNft(bytes[] calldata data) public {
        require(stakeNft[msg.sender].length >= 3, "The owner must stake 3 NFTs to create a new NFT");

        mint(data, address(this));
    }

    // Internal function to mint NFTs with location data and associated fees.
    function mint(bytes[] calldata data, address _owner) internal {
        require(data.length >= 7, "Insufficient data provided");

        uint256 arrayLength = data.length / 7;

        for (uint256 i = 0; i < arrayLength; i++) {
            uint256 baseIndex = i * 7;

            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();

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
            isStake[tokenId] = false;

            creatorNft[_owner].push(tokenId);
            previousOwner[tokenId] = _owner;
            emit createNFT(_owner, tokenId, fee);
        }
    }

    // Internal function to remove an element from an array.
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

    // Internal function to check if a given set of coordinates is within a location.
    function isOnPoint(euint32 lat, euint32 lng, Location memory location) internal view returns (bool) {
        return (TFHE.decrypt(TFHE.ge(lat, location.southLat)) &&
            TFHE.decrypt(TFHE.le(lat, location.northLat)) &&
            TFHE.decrypt(TFHE.ge(lng, location.westLon)) &&
            TFHE.decrypt(TFHE.le(lng, location.eastLon)));
    }

    function isLocationValid(uint256 locationId) public view returns (bool) {
        return locations[locationId].isValid;
    }

    // Function to stake NFTs by the sender.
    function stakeNFT(uint256[] calldata nftIndices) public {
        require(nftIndices.length > 0, "No NFTs to stake");

        for (uint256 i = 0; i < nftIndices.length; i++) {
            uint256 nftId = nftIndices[i];

            require(ownerOf(nftId) == msg.sender);
            require(!contains(stakeNft[msg.sender], nftId));

            stakeNft[msg.sender].push(nftId);
            isStake[nftId] = true;
            stakedNFTCount++;
            tokenStakeAddress[nftId] = msg.sender;
            _transfer(ownerOf(nftId), address(this), nftId);
        }
    }

    // Function to unstake NFTs by the sender.
    function unstakeNFT(uint256[] calldata nftIndices) public {
        require(nftIndices.length > 0, "No NFTs to unstake");

        for (uint256 i = 0; i < nftIndices.length; i++) {
            uint256 nftId = nftIndices[i];

            require(contains(stakeNft[msg.sender], nftId));

            removeElement(stakeNft[msg.sender], nftId);
            stakedNFTCount--;
            isStake[nftId] = false;
            delete tokenStakeAddress[nftId];
            _transfer(ownerOf(nftId), msg.sender, nftId);
        }
    }

    /**
     * @dev Checks GPS coordinates against a specified location's coordinates.
     * @param userLatitude The latitude of the user's location.
     * @param userLongitude The longitude of the user's location.
     * @param _tokenId The ID of the NFT being checked.
     * @return A boolean indicating whether the user's location is on the specified point.
     */
    function checkGps(
        bytes calldata userLatitude,
        bytes calldata userLongitude,
        uint256 _tokenId
    ) public payable returns (bool) {
        require(
            msg.value >= fees,
            string(abi.encodePacked("Insufficient fees. A minimum of ", fees, " ZAMA is required."))
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
            require(!isStake[_tokenId]);
            address previous = previousOwner[_tokenId];
            require(previous != msg.sender);

            uint256 nftFees = userFees[previous][_tokenId];
            uint256 totalTax = fees + nftFees;

            require(msg.value >= totalTax, "Insufficient funds to pay NFT tax");

            payable(previous).transfer(nftFees);
            locationsNonAccessible[_tokenId] = locations[_tokenId];

            delete userFees[previous][_tokenId];
            delete locations[_tokenId];
            delete previousOwner[_tokenId];
            delete creatorNft[previous];

            if (previous != address(this)) {
                removeElement(resetNft[previous], _tokenId);
            }
            previousOwner[_tokenId] = msg.sender;
            result = true;
            _transfer(ownerOf(_tokenId), msg.sender, _tokenId);
        }
        emit GpsCheckResult(msg.sender, result, _tokenId);
        return result;
    }

    /**
     * @dev Resets one or more NFTs, putting them back into the game.
     * @param tokenIds An array of NFT IDs to be reset.
     * @param taxes An array of corresponding taxes for each NFT to be reset.
     */
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
                tokenResetAddress[tokenId] = msg.sender;
                delete locationsNonAccessible[tokenId];
                emit ResetNFT(msg.sender, tokenId, true);
            }
        }
    }

    /**
     * @dev Cancels the reset of one or more NFTs.
     * @param tokenIds An array of NFT IDs to cancel the reset for.
     */
    function cancelResetNFT(uint256[] calldata tokenIds) public {
        require(tokenIds.length > 0, "No token IDs provided");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            if (contains(resetNft[msg.sender], tokenId)) {
                _transfer(address(this), msg.sender, tokenId);
                locationsNonAccessible[tokenId] = locations[tokenId];
                delete locations[tokenId];
                delete tokenResetAddress[tokenId];
                userFees[msg.sender][tokenId] = 0;
                removeElement(resetNft[msg.sender], tokenId);
                emit ResetNFT(msg.sender, tokenId, false);
            }
        }
    }
}
