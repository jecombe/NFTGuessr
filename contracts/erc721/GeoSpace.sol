pragma solidity ^0.8.20;

import "../libraries/Lib.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "fhevm/abstracts/EIP712WithModifier.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "fhevm/oracle/OracleCaller.sol";

import "../structs/StructsNftGuessr.sol";

contract GeoSpace is ERC721Enumerable, Ownable, EIP712WithModifier, OracleCaller {
    uint256 private _tokenIdCounter; // tokenCounter id NFT
    string private _baseTokenURI; // Don't use actually
    address public contractOwner;

    uint public lifeMint = 50;
    uint public subLife = 1;
    uint public addLife = 1;

    bool public yBool;
    ebool xBool;
    mapping(address => bool) public boolUsers;
    mapping(address => ebool) public eBoolUsers;

    mapping(address => uint[]) public tokenIdResetLife;
    mapping(address => uint) public lifePointTotal;
    mapping(address => uint) private saveLifePointTotal;

    //mapping(address => uint)

    mapping(uint => Location) private locations; // Mapping to store NFT locations and non-accessible locations.
    mapping(address => uint[]) public creatorNft; // To see all NFTsIDs back in game
    mapping(address => uint[]) public tokenIdOwned;
    mapping(address => mapping(uint => uint)) public userFees; // To see all fees for nfts address user
    mapping(uint => address) public ownerNft; // This variable is used to indirectly determine if a user is the owner of the NFT.
    mapping(uint => address) public tokenResetAddress; //  See address user NFT back in game with ID
    mapping(uint => address) public tokenCreationAddress; // See address user NFT creation with ID
    mapping(address => uint[]) public resetNft; // To see all NFTsIDs back in game
    mapping(address => uint[]) public winners;
    mapping(address => uint) public balanceRewardStaker;
    mapping(address => uint) public balanceRewardCreator;

    constructor(
        address _nftGuessr
    ) ERC721("GeoSpace", "GSP") EIP712WithModifier("Authorization token", "1") Ownable(_nftGuessr) {
        contractOwner = msg.sender;
        xBool = TFHE.asEbool(true);
    }

    modifier isOwner() {
        require(msg.sender == contractOwner, "you are not the owner");
        _;
    }
    /************************ GETTER FUNCTIONS *************************/
    // Function to get the total number of NFTs in existence.
    function getTotalNft() public view returns (uint) {
        return totalSupply();
    }

    function getIdsCreator(address player) external view returns (uint[] memory) {
        return creatorNft[player];
    }

    function getWinIds(address player) external view returns (uint[] memory) {
        return winners[player];
    }

    // Function to get an array of NFTs owned by a user.
    function getOwnedNFTs(address user) external view returns (uint[] memory) {
        uint[] memory ownedNFTs = new uint[](balanceOf(user));

        for (uint i = 0; i < balanceOf(user); i++) {
            ownedNFTs[i] = tokenOfOwnerByIndex(user, i);
        }

        return ownedNFTs;
    }

    // Function to get the IDs and fees of NFTs reset by a user.
    function getResetNFTsAndFeesByOwner(address user) external view returns (uint[] memory, uint[] memory) {
        uint[] memory resetNFTs = resetNft[user];
        uint[] memory nftFees = new uint[](resetNFTs.length);

        for (uint i = 0; i < resetNFTs.length; i++) {
            uint tokenId = resetNFTs[i];
            nftFees[i] = userFees[user][tokenId];
        }

        return (resetNFTs, nftFees);
    }

    // Function to get the IDs of NFTs reset by a user.
    function getNFTsResetByOwner(address _owner) external view returns (uint[] memory) {
        return resetNft[_owner];
    }

    // Function to get the creation IDs and fees of NFTs created by a user. (fees creator is for one round)
    function getNftCreationAndFeesByUser(address user) external view returns (uint[] memory, uint[] memory) {
        uint[] memory ids = new uint[](creatorNft[user].length);
        uint[] memory feesNft = new uint[](creatorNft[user].length);

        for (uint i = 0; i < creatorNft[user].length; i++) {
            uint tokenId = creatorNft[user][i];
            ids[i] = tokenId;
            feesNft[i] = userFees[user][tokenId];
        }

        return (ids, feesNft);
    }

    function getNftWinnerForUser(address user) external view returns (uint[] memory) {
        return winners[user];
    }

    function callbackBool(uint256 requestID, bool decryptedInput) public onlyOracle returns (bool) {
        //yBool = decryptedInput;
        address[] memory params = getParamsAddress(requestID);
        address player = address(params[0]);

        boolUsers[player] = decryptedInput;
        return boolUsers[player];
    }

    function isOnPoints(euint32 lat, euint32 lng, Location memory location, address _player) internal {
        ebool isLatSouth = TFHE.ge(lat, location.southLat); //if lat >= location.southLat => true if correct
        ebool isLatNorth = TFHE.le(lat, location.northLat); // if lat <= location.northLat => true if correct
        ebool isLatValid = TFHE.and(isLatSouth, isLatNorth);

        ebool isLngWest = TFHE.ge(lng, location.westLon); // true if correct
        ebool isLngEast = TFHE.le(lng, location.eastLon); // true if correct
        ebool isLngValid = TFHE.and(isLngWest, isLngEast);
        ebool[] memory cts = new ebool[](1);
        cts[0] = TFHE.and(isLngValid, isLatValid);
        uint256 requestID = Oracle.requestDecryption(cts, this.callbackBool.selector, 0, block.timestamp + 100);
        addParamsAddress(requestID, _player);
    }

    // Internal function to get strcture result get Location decrypt
    function getLocation(Location memory _location, bytes32 publicKey) internal view returns (NFTLocation memory) {
        bytes memory lat = TFHE.reencrypt(_location.lat, publicKey, 0);
        bytes memory lng = TFHE.reencrypt(_location.lng, publicKey, 0);
        return NFTLocation(lat, lng);
    }

    // Function to get the location of an NFT for owner smart contract using decrypted coordinates.
    function getNFTLocation(
        uint tokenId,
        bytes32 publicKey,
        bytes calldata signature
    ) external view onlySignedPublicKey(publicKey, signature) isOwner returns (NFTLocation memory) {
        return getLocation(locations[tokenId], publicKey);
    }
    // Function to get the address associated with the reset of an NFT.
    function getAddressResetWithToken(uint _tokenId) public view returns (address) {
        return tokenResetAddress[_tokenId];
    }

    // Function to get the location of an NFT for owner using decrypted coordinates.
    function getNFTLocationForOwner(
        uint tokenId,
        bytes32 publicKey,
        bytes calldata signature
    ) external view onlySignedPublicKey(publicKey, signature) returns (NFTLocation memory) {
        address resetAddr = getAddressResetWithToken(tokenId); // Check if user is reset (back in game) nft
        address creaAddr = tokenCreationAddress[tokenId]; // Check if user is the creator

        if (ownerOf(tokenId) == msg.sender) {
            return getLocation(locations[tokenId], publicKey);
        } else if (resetAddr == msg.sender || creaAddr == msg.sender) {
            return getLocation(locations[tokenId], publicKey);
        } else revert("your are not the owner");
    }

    //Function to see if location is valid
    function isLocationValid(uint locationId) internal view returns (bool) {
        return locations[locationId].isValid;
    }

    // Fonction pour vérifier si le joueur a déjà remporté ce NFT
    function isWinner(address joueur, uint nftId) public view returns (bool) {
        uint[] memory nftIds = winners[joueur];
        for (uint i = 0; i < nftIds.length; i++) {
            if (nftIds[i] == nftId) {
                return true;
            }
        }
        return false;
    }

    /************************ CHANGER FUNCTIONS *************************/

    function changeLifeMint(uint _lifeMint) external isOwner {
        lifeMint = _lifeMint;
    }
    function changeSubLife(uint _subLife) external isOwner {
        subLife = _subLife;
    }
    function changeAddLife(uint _addLife) external isOwner {
        addLife = _addLife;
    }

    function changeUserFees(uint tokenId, uint newFee) external {
        require(msg.sender == ownerNft[tokenId], "you are not the owner of GSP");
        userFees[msg.sender][tokenId] = newFee;
    }
    /************************ LIFE POINTS MINT FUNCTIONS *************************/
    function subLifePoint(address _ownerNft) external onlyOwner {
        lifePointTotal[_ownerNft] = lifePointTotal[_ownerNft] - subLife;
    }

    function subLifePointTotal(address _ownerNft) internal view returns (uint) {
        // Calculer combien de points vous devez enlever
        uint expectedTotalPointsLength = tokenIdResetLife[_ownerNft].length; // 2
        uint expectedTotalPoints = expectedTotalPointsLength * lifeMint; // 100
        uint pointsToRemove = expectedTotalPoints >= lifePointTotal[_ownerNft]
            ? expectedTotalPoints - lifePointTotal[_ownerNft]
            : 0;
        return pointsToRemove;
    }

    function saveLifePoints(address _ownerNft) internal {
        // Calculer combien de points vous devez enlever
        uint amtToRemove = subLifePointTotal(_ownerNft);
        if (amtToRemove < 1) return;
        saveLifePointTotal[_ownerNft] = saveLifePointTotal[_ownerNft] + amtToRemove;
        lifePointTotal[_ownerNft] = lifePointTotal[_ownerNft] - amtToRemove;
    }

    function addSaveLifePointsToTotal(address _ownerNft) internal {
        // Calculer combien de points vous devez enlever
        uint amtToAdd = saveLifePointTotal[_ownerNft];
        if (amtToAdd < 1) return;
        saveLifePointTotal[_ownerNft] = saveLifePointTotal[_ownerNft] - amtToAdd;
        lifePointTotal[_ownerNft] = lifePointTotal[_ownerNft] + amtToAdd;
    }

    function manageResetLifeMint(address player, uint tokenId) internal {
        if (!Lib.contains(tokenIdResetLife[player], tokenId)) {
            tokenIdResetLife[player].push(tokenId);
            lifePointTotal[player] = lifePointTotal[player] + lifeMint;
        } else {
            addSaveLifePointsToTotal(player);
        }
    }

    /************************ MINTING FUNCTIONS *************************/

    // Internal function to set data mapping and array for minting NFT GeoSpace function
    function setDataForMinting(address player, uint tokenId, uint feesToSet, Location memory locate) internal {
        locations[tokenId] = locate;
        userFees[player][tokenId] = feesToSet;
        creatorNft[player].push(tokenId);
        tokenCreationAddress[tokenId] = player;
        ownerNft[tokenId] = player;
        //A TEST
        // winningFees[tokenId] = feesToSet;
    }

    /*function isLocationAlreadyUsed(Location memory newLocation) internal view {
        for (uint i = 1; i <= getTotalNft(); i++) {
            //TFHE.optReq(TFHE.ne(newLocation.lat, locations[i].lat));
            TFHE.optReq(TFHE.ne(newLocation.lng, locations[i].lng));
        }
    }*/

    function mint(
        address player,
        bytes[] calldata data,
        uint feesData,
        uint baseIndex
    ) external onlyOwner returns (uint) {
        _tokenIdCounter++;
        uint tokenId = _tokenIdCounter;

        Location memory locate = Lib.createObjectLocation(data, baseIndex);

        // isLocationAlreadyUsed(locate);
        setDataForMinting(player, tokenId, feesData, locate);
        _mint(address(this), tokenId);
        return tokenId;
    }

    /************************ GAME FUNCTIONS *************************/
    function checkGps(
        address player,
        bytes calldata userLatitude,
        bytes calldata userLongitude,
        uint _tokenId
    ) external payable onlyOwner returns (bool) {
        // Convert bytes to euint32
        euint32 lat = TFHE.asEuint32(userLatitude);
        euint32 lng = TFHE.asEuint32(userLongitude);

        eBoolUsers[player] = TFHE.asEbool(false);

        uint totalSupply = totalSupply();

        require(_tokenId <= totalSupply, "Your token id is invalid");
        require(isLocationValid(_tokenId), "Location does not valid");
        require(ownerOf(_tokenId) != player, "you are the owner");
        require(tokenCreationAddress[_tokenId] != player, "you are the creator !");
        require(!isWinner(player, _tokenId), "You have already won this NFT.");

        address actualOwner = ownerNft[_tokenId];
        require(actualOwner != player, "you are the owner !"); // prevent
        isOnPoints(lat, lng, locations[_tokenId], player);
        if (boolUsers[player]) {
            resetMapping(_tokenId, actualOwner); // Reset data with delete
            Lib.removeElement(resetNft[actualOwner], _tokenId); // delete resetOwner from array mapping
            ownerNft[_tokenId] = player; // Allows recording the new owner for the reset (NFTs back in game).
            winners[player].push(_tokenId);
            boolUsers[player] = false;
            eBoolUsers[player] = TFHE.asEbool(false);
            _transfer(ownerOf(_tokenId), player, _tokenId); //Transfer nft to winner
            return true;
        }
        return false;
    }
    // Internal function to reset mapping
    function resetMapping(uint tokenId, address _ownerNft) internal {
        if (Lib.contains(tokenIdResetLife[_ownerNft], tokenId)) {
            uint amtLifeSub = subLifePointTotal(_ownerNft);
            if (amtLifeSub != 0) lifePointTotal[_ownerNft] = lifePointTotal[_ownerNft] - amtLifeSub;
        }
        delete userFees[_ownerNft][tokenId];
        // winningFees[tokenId] = 0;
        locations[tokenId].isValid = false;
        delete ownerNft[tokenId];
        delete tokenResetAddress[tokenId];
    }

    function resetNFT(address player, uint tokenId, uint tax) external onlyOwner {
        require(ownerOf(tokenId) == player, "You can only put your own NFT in the game");
        require(!Lib.contains(resetNft[player], tokenId), "NFT is already back in game");
        require(!Lib.contains(creatorNft[player], tokenId), "the creator cannot reset nft");

        manageResetLifeMint(player, tokenId);

        userFees[player][tokenId] = tax;
        resetNft[player].push(tokenId);
        ownerNft[tokenId] = ownerOf(tokenId);
        locations[tokenId].isValid = true;
        tokenResetAddress[tokenId] = player;
        //  winningFees[tokenId] = tax;
        _transfer(player, address(this), tokenId);
    }

    function cancelResetNFT(address player, uint tokenId) external onlyOwner {
        require(Lib.contains(resetNft[player], tokenId), "NFT is not back in game");
        require(!Lib.contains(creatorNft[player], tokenId), "the creator cannot cancel reset nft");

        saveLifePoints(player);

        locations[tokenId].isValid = false;
        delete tokenResetAddress[tokenId];
        userFees[player][tokenId] = 0;
        //  winningFees[tokenId] = 0;
        Lib.removeElement(resetNft[player], tokenId);
        _transfer(address(this), player, tokenId);
    }

    /**
     * @dev brun nft with id, reset mapping, delete location and all creations ids and address
     * @param tokenId An array of NFT IDs to cancel the reset for.
     */
    function burnNFT(uint tokenId) external isOwner {
        address actualOwner = ownerNft[tokenId];

        resetMapping(tokenId, actualOwner);
        delete locations[tokenId];
        delete creatorNft[actualOwner];
        delete tokenCreationAddress[tokenId];
        _burn(tokenId);
    }
}
