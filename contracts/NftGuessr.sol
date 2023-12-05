// @title NftGuessr - Smart contract for a location-based NFT guessing game.
// @author [Jérémy Combe]
// @notice This contract extends ERC721Enumerable for NFT functionality.
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import "./libraries/LibrariesNftGuessr.sol";
import "./structs/StructsNftGuessr.sol";

contract NftGuessr is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private _tokenIdCounter; // tokenCounter id NFT
    string private _baseTokenURI; // Don't use actually

    uint256 public nbNftStake = 3; // Number minimum stake to access right creation NFTs
    uint256 public stakedNFTCount = 0; // Counter all NFTs staked
    uint256 public fees = 1 ether; // Fees base

    // Mapping to store NFT locations and non-accessible locations.
    mapping(uint256 => Location) internal locations;
    // mapping(uint256 => Location) internal locationsNonAccessible;
    // Mapping to track NFT creators / stake / reset and their fees.
    mapping(address => uint256[]) public creatorNft; // To see all NFTsIDs back in game
    mapping(address => mapping(uint256 => uint256)) public userFees; // To see all fees for nfts address user
    mapping(uint256 => address) previousOwner; // This variable is used to indirectly determine if a user is the owner of the NFT.
    mapping(address => uint256[]) public stakeNft; // To see all NFTsIDs stake
    mapping(uint256 => bool) public isStake; // Boolean to check if tokenId is stake
    mapping(uint256 => address) public tokenStakeAddress; // see address user NFT stake with ID
    mapping(uint256 => address) public tokenResetAddress; //  see address user NFT back in game with ID
    mapping(uint256 => address) public tokenCreationAddress; //  see address user NFT creation with ID
    mapping(address => uint256[]) public resetNft; // To see all NFTsIDs back in game

    // Event emitted when a user checks the GPS coordinates against an NFT location.
    event GpsCheckResult(address indexed user, bool result, uint256 tokenId);
    // Event emitted when a new NFT is created.
    event createNFT(address indexed user, uint256 tokenId, uint256 fee);
    // Event emitted when an NFT is reset.
    event ResetNFT(address indexed user, uint256 tokenId, bool isReset);

    // Contract constructor initializes base token URI and owner.
    constructor() ERC721("GeoSpace", "GSP") {
        _baseTokenURI = "";
    }

    /************************ MODIFER FUNCTIONS *************************/

    // Check if user have access
    modifier isAccess() {
        require(stakeNft[msg.sender].length >= 3, "The owner must stake 3 NFTs to create a new NFT");
        _;
    }

    /************************ OWNER FUNCTIONS *************************/

    // Fonction pour permettre au propriétaire de récupérer les ETH
    function withdraw() external onlyOwner {
        // Récupérez le solde du contrat
        uint256 contractBalance = address(this).balance;

        // Vérifiez que le solde est supérieur à zéro

        // Transférez les fonds au propriétaire
        (bool success, ) = owner().call{ value: contractBalance }("");
        require(success, "Transfer failed");
    }

    /************************ FALLBACK FUNCTIONS *************************/

    // Fallback function to receive Ether.
    receive() external payable {}

    /************************ GETTER FUNCTIONS *************************/

    // Function to get the number of NFTs required to stake.
    function getNbStake() external view returns (uint256) {
        return nbNftStake;
    }

    // Function to get the total number of staked NFTs.
    function getTotalStakedNFTs() external view returns (uint256) {
        return stakedNFTCount;
    }

    // Function to get the location of an NFT for owner smart contract using decrypted coordinates.
    function getNFTLocation(uint256 tokenId) external view onlyOwner returns (NFTLocation memory) {
        //if (isLocationValid(tokenId)) {
        return getLocation(locations[tokenId]);
        //}
        // return getLocation(locationsNonAccessible[tokenId]);
    }

    // Function to get the location of an NFT for owner using decrypted coordinates.
    function getNFTLocationForOwner(uint256 tokenId) external view returns (NFTLocation memory) {
        address stakeAddr = getAddressStakeWithToken(tokenId); // Check if user is staker
        address resetAddr = getAddressResetWithToken(tokenId); // Check if user is reset (back in game) nft
        address creaAddr = getAddressCreationWithToken(tokenId); // Check if user is the creator

        if (ownerOf(tokenId) == msg.sender) {
            return getLocation(locations[tokenId]);
        } else if (stakeAddr == msg.sender) {
            return getLocation(locations[tokenId]);
        } else if (resetAddr == msg.sender || creaAddr == msg.sender) {
            return getLocation(locations[tokenId]);
        } else revert("Not Owner");
    }

    // Function to get the address associated with the reset of an NFT.
    function getAddressResetWithToken(uint256 _tokenId) public view returns (address) {
        return tokenResetAddress[_tokenId];
    }

    // Function to get the address associated with the creation of an NFT.
    function getAddressCreationWithToken(uint256 _tokenId) public view returns (address) {
        return tokenCreationAddress[_tokenId];
    }

    // Function to get the address associated with the staking of an NFT.
    function getAddressStakeWithToken(uint256 _tokenId) public view returns (address) {
        return tokenStakeAddress[_tokenId];
    }

    // Function to get the fee associated with a user and an NFT.
    function getFee(address user, uint256 id) external view returns (uint256) {
        return userFees[user][id];
    }

    // Function to get an array of NFTs owned by a user.
    function getOwnedNFTs(address user) external view returns (uint256[] memory) {
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

    /************************ CHANGER FUNCTIONS *************************/

    // Function to change the fees required for NFT operations.
    function changeFees(uint256 _fees) external onlyOwner {
        fees = _fees.mul(1 ether);
    }

    // Function to change the number of NFTs required to stake.
    function changeNbNftStake(uint256 _nb) external onlyOwner {
        nbNftStake = _nb;
    }

    // Function to change the owner of the contract.
    function changeOwner(address _newOwner) external onlyOwner {
        transferOwnership(_newOwner);
    }

    /************************ INTERNAL FUNCTIONS *************************/

    // Internal function to return the base URI for metadata.
    function _baseURI() internal view virtual override(ERC721) returns (string memory) {
        return _baseTokenURI;
    }

    // Function internal to get strcture result get Location decrypt
    function getLocation(Location memory _location) internal view returns (NFTLocation memory) {
        uint32 northLat = TFHE.decrypt(_location.northLat);
        uint32 southLat = TFHE.decrypt(_location.southLat);
        uint32 eastLon = TFHE.decrypt(_location.eastLon);
        uint32 westLon = TFHE.decrypt(_location.westLon);
        uint lat = TFHE.decrypt(_location.lat);
        uint lng = TFHE.decrypt(_location.lng);
        NFTLocation memory nftLocation = NFTLocation(northLat, southLat, eastLon, westLon, lat, lng);
        return nftLocation;
    }

    // Function internal to check if location does exist for creation
    function isLocationAlreadyUsed(Location memory newLocation) internal view {
        for (uint256 i = 1; i <= getTotalNft(); i++) {
            TFHE.optReq(TFHE.ne(newLocation.lat, locations[i].lat));
            TFHE.optReq(TFHE.ne(newLocation.lng, locations[i].lng));
        }
    }

    // Function internal to check if user has enough funds to pay NFT tax.
    function checkFees(uint256 _tokenId, address previous) internal view returns (uint256) {
        uint256 nftFees = userFees[previous][_tokenId];
        uint256 totalTax = fees.add(nftFees);

        if (msg.value >= totalTax) {
            return 0; // Les frais sont suffisants
        } else {
            return totalTax.sub(msg.value); // Montant manquant
        }
    }

    // Internal function to mint NFTs with location data and associated fees.
    function mint(bytes[] calldata data, address _owner, uint256[] calldata feesData) internal {
        require(data.length >= 6, "Insufficient data provided");

        uint256 arrayLength = data.length / 6;

        for (uint256 i = 0; i < arrayLength; i++) {
            uint256 baseIndex = i * 6;

            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();

            Location memory locate = Location({
                northLat: TFHE.asEuint32(data[baseIndex]),
                southLat: TFHE.asEuint32(data[baseIndex + 1]),
                eastLon: TFHE.asEuint32(data[baseIndex + 2]),
                westLon: TFHE.asEuint32(data[baseIndex + 3]),
                lat: TFHE.asEuint32(data[baseIndex + 4]),
                lng: TFHE.asEuint32(data[baseIndex + 5]),
                isValid: true
            });

            isLocationAlreadyUsed(locate);

            locations[tokenId] = locate;
            _mint(_owner, tokenId);
            userFees[msg.sender][tokenId] = feesData[i];
            isStake[tokenId] = false;

            creatorNft[msg.sender].push(tokenId);
            tokenCreationAddress[tokenId] = msg.sender;
            previousOwner[tokenId] = msg.sender;
            emit createNFT(_owner, tokenId, feesData[i]);
        }
    }

    /************************ INTERNAL FUNCTIONS UTILES *************************/

    //Function to reset mapping
    function resetMapping(uint256 tokenId, address previous) internal {
        delete userFees[previous][tokenId];
        locations[tokenId].isValid = false;
        delete previousOwner[tokenId];
        delete creatorNft[previous];
        delete tokenResetAddress[tokenId];
        delete tokenCreationAddress[tokenId];
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

    // Function to burn (destroy) an NFT, only callable by the owner.
    function burnNFT(uint256 tokenId) external onlyOwner {
        address previous = previousOwner[tokenId];

        resetMapping(tokenId, previous);
        delete locations[tokenId];
        delete isStake[tokenId];
        _burn(tokenId);
    }

    //Function to see if location is valid
    function isLocationValid(uint256 locationId) public view returns (bool) {
        return locations[locationId].isValid;
    }

    /************************ GAMING FUNCTIONS *************************/

    /**
     * @dev createGPS one or more NFTs, with tax just for owner smart contract.
     * @param data An array of NFT GPS coordinates to be create.
     * @param feesData An array of fees to be create corresponding of array data.
     */
    function createGpsOwner(bytes[] calldata data, uint256[] calldata feesData) external onlyOwner {
        mint(data, address(this), feesData);
    }

    /**
     * @dev createGPS one or more NFTs, with tax just for owner nft.
     * @param data An array of NFT GPS coordinates to be create.
     * @param feesData An array of fees to be create corresponding of array data.
     */
    function createGpsOwnerNft(bytes[] calldata data, uint256[] calldata feesData) external isAccess {
        mint(data, address(this), feesData);
    }

    /**
     * @dev Stake one or more NFTs, with tax.
     * @param nftIndices An array of NFT IDs to be stake.
     */
    function stakeNFT(uint256[] calldata nftIndices) external {
        require(nftIndices.length > 0, "No NFTs to stake");

        for (uint256 i = 0; i < nftIndices.length; i++) {
            uint256 nftId = nftIndices[i];

            require(ownerOf(nftId) == msg.sender, "you are not the owner");
            require(!contains(stakeNft[msg.sender], nftId), "NFT is already stake, please unstake before");
            require(!contains(creatorNft[msg.sender], nftId), "the creator cannot stake nft");

            stakeNft[msg.sender].push(nftId);
            isStake[nftId] = true;
            stakedNFTCount++;
            tokenStakeAddress[nftId] = msg.sender;
            _transfer(ownerOf(nftId), address(this), nftId);
        }
    }

    /**
     * @dev Unstake one or more NFTs, delete tax.
     * @param nftIndices An array of NFT IDs to be unstake.
     */
    function unstakeNFT(uint256[] calldata nftIndices) external {
        require(nftIndices.length > 0, "No NFTs to unstake");

        for (uint256 i = 0; i < nftIndices.length; i++) {
            uint256 nftId = nftIndices[i];
            require(!contains(creatorNft[msg.sender], nftId), "the creator cannot unstake nft");
            require(contains(stakeNft[msg.sender], nftId), "NFT is stake, please unstake");

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
    ) external payable returns (bool) {
        require(
            msg.value >= fees,
            string(abi.encodePacked("Insufficient fees. A minimum of ", fees, " ZAMA is required."))
        );
        // Convert bytes to euint32
        euint32 lat = TFHE.asEuint32(userLatitude);
        euint32 lng = TFHE.asEuint32(userLongitude);

        bool result = false;
        uint256 totalSupply = totalSupply();

        require(_tokenId <= totalSupply, "Your token id is invalid");
        require(isLocationValid(_tokenId), "Location does not valid");

        if (isOnPoint(lat, lng, locations[_tokenId])) {
            require(ownerOf(_tokenId) != msg.sender, "you are the owner");
            require(!isStake[_tokenId], "NFT is stake");

            address previous = previousOwner[_tokenId];

            require(previous != msg.sender, "you are the owner");

            uint256 missingFunds = checkFees(_tokenId, previousOwner[_tokenId]);

            require(missingFunds == 0, string(abi.encodePacked("Insufficient funds. Missing ", missingFunds, " wei")));

            payable(previous).transfer(userFees[previous][_tokenId]);
            // locationsNonAccessible[_tokenId] = locations[_tokenId]; // This prevents a location from being present when it belongs to a user.

            resetMapping(_tokenId, previous); // Reset data with delete

            if (previous != address(this)) {
                removeElement(resetNft[previous], _tokenId);
            }
            previousOwner[_tokenId] = msg.sender; // Allows recording the new owner for the reset (NFTs back in game).
            result = true;
            _transfer(ownerOf(_tokenId), msg.sender, _tokenId); //Transfer nft to winner
        }
        emit GpsCheckResult(msg.sender, result, _tokenId);
        return result;
    }

    /**
     * @dev Resets one or more NFTs, putting them back into the game.
     * @param tokenIds An array of NFT IDs to be reset.
     * @param taxes An array of corresponding taxes for each NFT to be reset.
     */
    function resetNFT(uint256[] calldata tokenIds, uint256[] calldata taxes) external {
        require(tokenIds.length > 0, "No token IDs provided");
        require(tokenIds.length == taxes.length, "Invalid input lengths");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 tax = taxes[i];

            require(ownerOf(tokenId) == msg.sender, "You can only put your own NFT in the game");
            require(!contains(stakeNft[msg.sender], tokenId), "NFT is staked, please unstake before");
            require(!contains(resetNft[msg.sender], tokenId), "NFT is already back in game");
            require(!contains(creatorNft[msg.sender], tokenId), "the creator cannot reset nft");

            userFees[msg.sender][tokenId] = tax;
            resetNft[msg.sender].push(tokenId);
            previousOwner[tokenId] = ownerOf(tokenId);
            locations[tokenId].isValid = true;
            tokenResetAddress[tokenId] = msg.sender;
            _transfer(msg.sender, address(this), tokenId);
            emit ResetNFT(msg.sender, tokenId, true);
        }
    }

    /**
     * @dev Cancels the reset of one or more NFTs.
     * @param tokenIds An array of NFT IDs to cancel the reset for.
     */
    function cancelResetNFT(uint256[] calldata tokenIds) external {
        require(tokenIds.length > 0, "No token IDs provided");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            require(contains(resetNft[msg.sender], tokenId), "NFT is not back in game");
            require(!contains(creatorNft[msg.sender], tokenId), "the creator cannot reset nft");

            locations[tokenId].isValid = false;
            delete tokenResetAddress[tokenId];
            userFees[msg.sender][tokenId] = 0;
            removeElement(resetNft[msg.sender], tokenId);
            _transfer(address(this), msg.sender, tokenId);
            emit ResetNFT(msg.sender, tokenId, false);
        }
    }
}
