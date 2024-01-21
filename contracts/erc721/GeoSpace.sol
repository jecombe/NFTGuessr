pragma solidity ^0.8.19;

import "../libraries/Lib.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "fhevm/abstracts/EIP712WithModifier.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../structs/StructsNftGuessr.sol";

contract GeoSpace is ERC721Enumerable, Ownable, EIP712WithModifier {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter public _tokenIdCounter; // tokenCounter id NFT
    string private _baseTokenURI; // Don't use actually
    address public contractOwner;

    uint public lifeMint = 50;
    uint public subLife = 1;
    uint public addLife = 1;
    mapping(address => uint256[]) public tokenIdResetLife;
    mapping(address => mapping(uint256 => uint256)) public tokenIdPoints;
    mapping(address => uint256) public lifePointTotal;
    mapping(address => uint256) public saveLifePointTotal;

    //mapping(address => uint256)

    mapping(uint256 => Location) private locations; // Mapping to store NFT locations and non-accessible locations.
    mapping(address => uint256[]) public creatorNft; // To see all NFTsIDs back in game
    mapping(address => mapping(uint256 => uint256)) public userFees; // To see all fees for nfts address user
    mapping(uint256 => address) public ownerNft; // This variable is used to indirectly determine if a user is the owner of the NFT.
    mapping(uint256 => address) public tokenResetAddress; //  See address user NFT back in game with ID
    mapping(uint256 => address) public tokenCreationAddress; // See address user NFT creation with ID
    mapping(address => uint256[]) public resetNft; // To see all NFTsIDs back in game
    mapping(address => uint[]) public winners;
    mapping(address => uint256) public balanceRewardStaker;
    mapping(address => uint256) public balanceRewardCreator;

    constructor(address _nftGuessr) ERC721("GeoSpace", "GSP") EIP712WithModifier("Authorization token", "1") {
        transferOwnership(_nftGuessr);
        contractOwner = msg.sender;
    }

    modifier isOwner() {
        require(msg.sender == contractOwner, "you are not the owner");
        _;
    }
    /************************ GETTER FUNCTIONS *************************/
    // Function to get the total number of NFTs in existence.
    function getTotalNft() public view returns (uint256) {
        return totalSupply();
    }

    function getIdsCreator(address player) external view returns (uint256[] memory) {
        return creatorNft[player];
    }

    // Internal function internal to check if location does exist for creation
    function isLocationAlreadyUsed(Location memory newLocation) internal view {
        for (uint256 i = 1; i <= getTotalNft(); i++) {
            TFHE.optReq(TFHE.ne(newLocation.lat, locations[i].lat));
            TFHE.optReq(TFHE.ne(newLocation.lng, locations[i].lng));
        }
    }

    // Function to get an array of NFTs owned by a user.
    function getOwnedNFTs(address user) external view returns (uint256[] memory) {
        uint256[] memory ownedNFTs = new uint256[](balanceOf(user));

        for (uint256 i = 0; i < balanceOf(user); i++) {
            ownedNFTs[i] = tokenOfOwnerByIndex(user, i);
        }

        return ownedNFTs;
    }

    // Function to get the IDs and fees of NFTs reset by a user.
    function getResetNFTsAndFeesByOwner(address user) external view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory resetNFTs = resetNft[user];
        uint256[] memory nftFees = new uint256[](resetNFTs.length);

        for (uint256 i = 0; i < resetNFTs.length; i++) {
            uint256 tokenId = resetNFTs[i];
            nftFees[i] = userFees[user][tokenId];
        }

        return (resetNFTs, nftFees);
    }

    // Function to get the IDs of NFTs reset by a user.
    function getNFTsResetByOwner(address _owner) external view returns (uint256[] memory) {
        return resetNft[_owner];
    }

    // Function to get the creation IDs and fees of NFTs created by a user. (fees creator is for one round)
    function getNftCreationAndFeesByUser(address user) external view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory ids = new uint256[](creatorNft[user].length);
        uint256[] memory feesNft = new uint256[](creatorNft[user].length);

        for (uint256 i = 0; i < creatorNft[user].length; i++) {
            uint256 tokenId = creatorNft[user][i];
            ids[i] = tokenId;
            feesNft[i] = userFees[user][tokenId];
        }

        return (ids, feesNft);
    }

    function getNftWinnerForUser(address user) external view returns (uint256[] memory) {
        return winners[user];
    }

    // Internal function to get strcture result get Location decrypt
    function getLocation(Location memory _location, bytes32 publicKey) internal view returns (NFTLocation memory) {
        bytes memory lat = TFHE.reencrypt(_location.lat, publicKey, 0);
        bytes memory lng = TFHE.reencrypt(_location.lng, publicKey, 0);
        return NFTLocation(lat, lng);
    }

    // Function to get the location of an NFT for owner smart contract using decrypted coordinates.
    function getNFTLocation(
        uint256 tokenId,
        bytes32 publicKey,
        bytes calldata signature
    ) external view onlySignedPublicKey(publicKey, signature) isOwner returns (NFTLocation memory) {
        return getLocation(locations[tokenId], publicKey);
    }
    // Function to get the address associated with the reset of an NFT.
    function getAddressResetWithToken(uint256 _tokenId) public view returns (address) {
        return tokenResetAddress[_tokenId];
    }

    // Function to get the location of an NFT for owner using decrypted coordinates.
    function getNFTLocationForOwner(
        uint256 tokenId,
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
    function isLocationValid(uint256 locationId) internal view returns (bool) {
        return locations[locationId].isValid;
    }

    // Fonction pour vérifier si le joueur a déjà remporté ce NFT
    function isWinner(address joueur, uint256 nftId) public view returns (bool) {
        uint[] memory nftIds = winners[joueur];
        for (uint256 i = 0; i < nftIds.length; i++) {
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
        lifePointTotal[_ownerNft] = lifePointTotal[_ownerNft].sub(subLife);
    }

    function subLifePointTotal(address _ownerNft) internal view returns (uint) {
        // Calculer combien de points vous devez enlever
        uint256 expectedTotalPointsLength = tokenIdResetLife[_ownerNft].length; // 2
        uint256 expectedTotalPoints = expectedTotalPointsLength.mul(lifeMint); // 100
        uint256 pointsToRemove = expectedTotalPoints > lifePointTotal[_ownerNft]
            ? expectedTotalPoints.sub(lifePointTotal[_ownerNft])
            : 0;
        return pointsToRemove;
    }

    function saveLifePoints(address _ownerNft) internal {
        // Calculer combien de points vous devez enlever
        uint amtToRemove = subLifePointTotal(_ownerNft);
        if (amtToRemove < 1) return;
        saveLifePointTotal[_ownerNft] = saveLifePointTotal[_ownerNft].add(amtToRemove);
        lifePointTotal[_ownerNft] = lifePointTotal[_ownerNft].sub(amtToRemove);
    }

    function addSaveLifePointsToTotal(address _ownerNft) internal {
        // Calculer combien de points vous devez enlever
        uint amtToAdd = saveLifePointTotal[_ownerNft];
        if (amtToAdd < 1) return;
        saveLifePointTotal[_ownerNft] = saveLifePointTotal[_ownerNft].sub(amtToAdd);
        lifePointTotal[_ownerNft] = lifePointTotal[_ownerNft].add(amtToAdd);
    }

    function manageResetLifeMint(address player, uint tokenId) internal {
        if (!Lib.contains(tokenIdResetLife[player], tokenId)) {
            tokenIdResetLife[player].push(tokenId);
            lifePointTotal[player] = lifePointTotal[player].add(lifeMint);
        } else {
            addSaveLifePointsToTotal(player);
        }
    }

    /************************ MINTING FUNCTIONS *************************/

    // Internal function to set data mapping and array for minting NFT GeoSpace function
    function setDataForMinting(address player, uint256 tokenId, uint256 feesToSet, Location memory locate) internal {
        locations[tokenId] = locate;
        userFees[player][tokenId] = feesToSet;
        creatorNft[player].push(tokenId);
        tokenCreationAddress[tokenId] = player;
        ownerNft[tokenId] = player;
        //A TEST
        // winningFees[tokenId] = feesToSet;
    }

    function mint(
        address player,
        bytes[] calldata data,
        uint256 feesData,
        uint256 baseIndex
    ) external onlyOwner returns (uint256) {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        Location memory locate = Lib.createObjectLocation(data, baseIndex);

        isLocationAlreadyUsed(locate);
        setDataForMinting(player, tokenId, feesData, locate);
        _mint(address(this), tokenId);
        return tokenId;
    }

    /************************ GAME FUNCTIONS *************************/
    function checkGps(
        address player,
        bytes calldata userLatitude,
        bytes calldata userLongitude,
        uint256 _tokenId
    ) external payable onlyOwner returns (bool) {
        // Convert bytes to euint32
        euint32 lat = TFHE.asEuint32(userLatitude);
        euint32 lng = TFHE.asEuint32(userLongitude);

        uint256 totalSupply = totalSupply();

        require(_tokenId <= totalSupply, "Your token id is invalid");
        require(isLocationValid(_tokenId), "Location does not valid");
        require(ownerOf(_tokenId) != player, "you are the owner");
        require(tokenCreationAddress[_tokenId] != player, "you are the creator !");
        require(!isWinner(player, _tokenId), "You have already won this NFT.");

        address actualOwner = ownerNft[_tokenId];
        require(actualOwner != player, "you are the owner !"); // prevent

        if (Lib.isOnPoint(lat, lng, locations[_tokenId])) {
            resetMapping(_tokenId, actualOwner); // Reset data with delete
            Lib.removeElement(resetNft[actualOwner], _tokenId); // delete resetOwner from array mapping
            ownerNft[_tokenId] = player; // Allows recording the new owner for the reset (NFTs back in game).
            winners[player].push(_tokenId);
            _transfer(ownerOf(_tokenId), player, _tokenId); //Transfer nft to winner
            return true;
        }
        return false;
    }
    // Internal function to reset mapping
    function resetMapping(uint256 tokenId, address _ownerNft) internal {
        if (Lib.contains(tokenIdResetLife[_ownerNft], tokenId)) {
            uint256 amtLifeSub = subLifePointTotal(_ownerNft);
            if (amtLifeSub != 0) lifePointTotal[_ownerNft] = lifePointTotal[_ownerNft].sub(amtLifeSub);
        }
        delete userFees[_ownerNft][tokenId];
        // winningFees[tokenId] = 0;
        locations[tokenId].isValid = false;
        delete ownerNft[tokenId];
        delete tokenResetAddress[tokenId];
    }

    function resetNFT(address player, uint256 tokenId, uint256 tax) external onlyOwner {
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

    function cancelResetNFT(address player, uint256 tokenId) external onlyOwner {
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
    function burnNFT(uint256 tokenId) external isOwner {
        address actualOwner = ownerNft[tokenId];

        resetMapping(tokenId, actualOwner);
        delete locations[tokenId];
        delete creatorNft[actualOwner];
        delete tokenCreationAddress[tokenId];
        _burn(tokenId);
    }
}
