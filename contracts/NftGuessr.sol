// @title NftGuessr - Smart contract for a location-based NFT guessing game.
// @author [Jérémy Combe]
// @notice This contract extends ERC721Enumerable for NFT functionality.
// SPDX-License-Identifier: MIT

/* *******************************************************************
For now, Zama does not handle negative integers.
So you need to use positive latitude and longitude values.
Here are the available data:

For West EU :
Latitude : 0 à 70 degrés (nord)
Longitude : 0 à 30 degrés (est)

For Noth EU:
Latitude : 50 à 70 degrés (nord)
Longitude : 0 à 30 degrés (est)

For North America:
Latitude : 0 à 70 degrés (nord)
Longitude : 70 à 170 degrés (ouest)

For East Asia:
Latitude : 0 à 50 degrés (nord)
Longitude : 90 à 180 degrés (est)
******************************************************************* */

pragma solidity ^0.8.19;
import "./libraries/LibrariesNftGuessr.sol";
import "./structs/StructsNftGuessr.sol";
import "./erc20/Erc20.sol";

contract NftGuessr is ERC721Enumerable, Ownable {
    /* LIBRARIES */
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private _tokenIdCounter; // tokenCounter id NFT
    string private _baseTokenURI; // Don't use actually
    address public contractOwner;

    /* STAKER */
    uint256 public nbNftStake = 3; // Number minimum stake to access right creation NFTs

    /* CREATOR */
    address[] public creatorNftAddresses; //  Save all address creators of NFT GeoSpace, can be add, but can't remove element

    /* FEES */
    uint256 public fees = 1 ether; // Fees (Zama) base
    uint256 public feesCreation = 1; // Fees (SPC) nft creation Geospace

    /* ERROR */
    euint8 internal NO_ERROR; // To check if error is present for checkGps
    euint8 internal ERROR; // To check if error is not present for checkGps
    /* ERC20 */
    CoinSpace private coinSpace; // CoinSpace interface token Erc20
    uint256 public amountMintErc20 = 2; // Number of mint token  when user call createGpsForOwner.
    uint256 public amountRewardUser = 2; // amount reward winner
    uint256 public amountRewardUsers = 1; // amount reward staker daily 24h.

    /* MAPPING */
    mapping(uint256 => Location) internal locations; // Mapping to store NFT locations and non-accessible locations.
    mapping(address => uint256[]) public creatorNft; // To see all NFTsIDs back in game
    mapping(address => mapping(uint256 => uint256)) public userFees; // To see all fees for nfts address user
    mapping(uint256 => address) ownerNft; // This variable is used to indirectly determine if a user is the owner of the NFT.
    mapping(address => uint256[]) public stakeNft; // To see all NFTsIDs stake
    mapping(uint256 => bool) public isStake; // Boolean to check if tokenId is stake
    mapping(uint256 => address) public tokenStakeAddress; // see address user NFT stake with ID
    mapping(uint256 => address) public tokenResetAddress; //  see address user NFT back in game with ID
    mapping(uint256 => address) public tokenCreationAddress; //  see address user NFT creation with ID
    mapping(address => uint256[]) public resetNft; // To see all NFTsIDs back in game

    address[] public stakerReward; // address for all staker if have 1 NFT GeoSpace stake can be add or remove element
    mapping(address => bool) stakersRewards;

    /* EVENT */
    event GpsCheckResult(address indexed user, bool result, uint256 tokenId); // Event emitted when a user checks the GPS coordinates against an NFT location.
    event createNFT(address indexed user, uint256 tokenId, uint256 fee); // Event emitted when a new NFT is created.
    event ResetNFT(address indexed user, uint256 tokenId, bool isReset, uint256 tax); // Event emitted when an NFT is reset.
    event RewardWithERC20(address indexed user, uint256 amount); // Event to see when user receive reward token.
    event StakingNFT(address indexed user, uint256 tokenId, uint256 timestamp, bool isStake); // Event to see stake / unstake

    // Contract constructor initializes base token URI and owner.
    constructor() ERC721("GeoSpace", "GSP") {
        _baseTokenURI = "";
        NO_ERROR = TFHE.asEuint8(0);
        ERROR = TFHE.asEuint8(1);
        contractOwner = msg.sender;
    }

    /************************ MODIFER FUNCTIONS *************************/

    // Check if user have access
    modifier isAccess() {
        require(stakeNft[msg.sender].length >= 3, "The owner must stake 3 NFTs to create a new NFT");
        _;
    }

    /************************ OWNER FUNCTIONS *************************/

    // Withdraw for owner smart contract
    function withdraw() external onlyOwner {
        uint256 contractBalance = address(this).balance;

        (bool success, ) = owner().call{ value: contractBalance }("");

        require(success, "Transfer failed");
    }

    // Withdraw token for owner smart contract
    function withdrawToken(uint256 _amount) external onlyOwner {
        require(coinSpace.transfer(owner(), _amount), "Token transfer failed");
    }

    // Change tokenAddress Erc20
    function setAddressToken(address _tokenErc20) external onlyOwner {
        coinSpace = CoinSpace(_tokenErc20);
    }

    // Function to reward the user with ERC-20 tokens script launch every 24 hours and check if user have receive rward in a same day.
    function rewardUsersWithERC20() external onlyOwner {
        for (uint256 i = 0; i < stakerReward.length; i++) {
            if (stakerReward[i] != contractOwner) {
                rewardUserWithERC20(stakerReward[i], amountRewardUsers);
            }
        }
    }

    /************************ FALLBACK FUNCTIONS *************************/

    // Fallback function to receive Ether.
    receive() external payable {}

    /************************ GETTER FUNCTIONS *************************/

    //get balance user SPC
    function getBalanceCoinSpace(address user) public view returns (uint256) {
        return coinSpace.balanceOf(user);
    }

    // Function to get the location of an NFT for owner smart contract using decrypted coordinates.
    function getNFTLocation(uint256 tokenId) external view onlyOwner returns (NFTLocation memory) {
        return getLocation(locations[tokenId]);
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
        } else revert("your are not the owner");
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

    // Function to get the creation IDs and fees of NFTs created by a user. (fees creator is for one round)
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

    //Function to see if location is valid
    function isLocationValid(uint256 locationId) public view returns (bool) {
        return locations[locationId].isValid;
    }

    // Check if user have access to creation NFT GeoSpace (3 NFT GeoSpace minimum stake)
    function isAccessCreation(address user) public view returns (bool) {
        return stakeNft[user].length >= nbNftStake;
    }

    /************************ CHANGER FUNCTIONS *************************/

    // Function to change the fees required for NFT operations.
    function changeFees(uint256 _fees) external onlyOwner {
        fees = _fees.mul(1 ether);
    }

    // Function to change the fees required for NFT creation.
    function changeFeesCreation(uint256 _feesCreation) external onlyOwner {
        feesCreation = _feesCreation;
    }

    //Function to change reward checkGps in SPC
    function changeRewardUser(uint256 _amountReward) external onlyOwner {
        amountRewardUser = _amountReward;
    }

    //Function to change reward user daily 24h in SPC
    function changeRewardUsers(uint256 _amountReward) external onlyOwner {
        amountRewardUsers = _amountReward;
    }

    // Function to change the number of NFTs required to stake.
    function changeNbNftStake(uint256 _nb) external onlyOwner {
        nbNftStake = _nb;
    }

    // Function to change amount mint with function createGpsOwnerNft
    function changeAmountMintErc20(uint256 _amountMintErc20) external onlyOwner {
        amountMintErc20 = _amountMintErc20;
    }

    // Function to change the owner of the contract.
    function changeOwner(address _newOwner) external onlyOwner {
        contractOwner = _newOwner;
        transferOwnership(_newOwner);
    }

    /************************ INTERNAL FUNCTIONS *************************/

    // Internal function to return the base URI for metadata.
    function _baseURI() internal view virtual override(ERC721) returns (string memory) {
        return _baseTokenURI;
    }

    //Internal funtion to distribute fees SPC for all creator
    function distributeFeesToCreators() internal {
        uint256 totalCreators = creatorNftAddresses.length;
        if (totalCreators > 0 && feesCreation > 0) {
            uint256 feeShare = (feesCreation * (10 ** 18)) / totalCreators;

            for (uint256 i = 0; i < totalCreators; i++) {
                address creator = creatorNftAddresses[i];
                if (creator != msg.sender) {
                    coinSpace.transfer(creator, feeShare);
                }
            }
        }
    }

    // Internal function to get strcture result get Location decrypt
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

    // Internal function internal to check if location does exist for creation
    function isLocationAlreadyUsed(Location memory newLocation) internal view {
        for (uint256 i = 1; i <= getTotalNft(); i++) {
            TFHE.optReq(TFHE.ne(newLocation.lat, locations[i].lat));
            TFHE.optReq(TFHE.ne(newLocation.lng, locations[i].lng));
        }
    }

    // Internal function to check if user has enough funds to pay NFT tax.
    function checkFees(uint256 _tokenId, address _ownerNft) internal view returns (uint256) {
        uint256 nftFees = userFees[_ownerNft][_tokenId];
        uint256 totalTax = fees.add(nftFees);

        if (msg.value >= totalTax) {
            return 0; // fees enough
        } else {
            return totalTax.sub(msg.value); //fees need
        }
    }

    // Internal function to set data mapping and array for minting NFT GeoSpace function
    function setDataForMinting(uint256 tokenId, uint256 feesToSet, Location memory locate) internal {
        locations[tokenId] = locate;
        userFees[msg.sender][tokenId] = feesToSet;
        isStake[tokenId] = false;

        creatorNft[msg.sender].push(tokenId);
        tokenCreationAddress[tokenId] = msg.sender;
        ownerNft[tokenId] = msg.sender;

        if (!containsAddress(creatorNftAddresses, msg.sender)) {
            creatorNftAddresses.push(msg.sender);
        }
    }

    // Internal function to create object Location with conversion FHE bytes to euint
    function createObjectLocation(bytes[] calldata data, uint256 baseIndex) internal pure returns (Location memory) {
        return
            Location({
                northLat: TFHE.asEuint32(data[baseIndex]),
                southLat: TFHE.asEuint32(data[baseIndex + 1]),
                eastLon: TFHE.asEuint32(data[baseIndex + 2]),
                westLon: TFHE.asEuint32(data[baseIndex + 3]),
                lat: TFHE.asEuint32(data[baseIndex + 4]),
                lng: TFHE.asEuint32(data[baseIndex + 5]),
                isValid: true
            });
    }

    // Internal function to mint NFTs with location data and associated fees.
    function mint(bytes[] calldata data, address _owner, uint256[] calldata feesData) internal {
        require(data.length >= 6, "Insufficient data provided");

        uint256 arrayLength = data.length / 6;

        for (uint256 i = 0; i < arrayLength; i++) {
            uint256 baseIndex = i * 6;

            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();

            Location memory locate = createObjectLocation(data, baseIndex);

            isLocationAlreadyUsed(locate);
            setDataForMinting(tokenId, feesData[i], locate);
            _mint(_owner, tokenId);

            emit createNFT(_owner, tokenId, feesData[i]);
        }
    }

    // Internal function to reward the user with ERC-20 tokens
    function rewardUserWithERC20(address user, uint256 amountReward) internal {
        uint256 rewardAmount = amountReward * 10 ** uint256(coinSpace.decimals());
        coinSpace.transfer(user, rewardAmount);

        emit RewardWithERC20(user, rewardAmount);
    }

    // Internal function to create transaction from msg.sender to smart contract
    function transactionCoinSpace() internal {
        uint256 amountToTransfer = feesCreation * 10 ** 18;

        require(getBalanceCoinSpace(msg.sender) >= amountToTransfer, "Insufficient ERC-20 balance");
        require(coinSpace.allowance(msg.sender, address(this)) >= amountToTransfer, "Insufficient allowance");
        require(coinSpace.transferFrom(msg.sender, address(this), amountToTransfer), "Transfer failed");
    }

    /************************ INTERNAL FUNCTIONS UTILS *************************/

    // Internal function to reset mapping
    function resetMapping(uint256 tokenId, address _ownerNft) internal {
        delete userFees[_ownerNft][tokenId];
        locations[tokenId].isValid = false;
        delete ownerNft[tokenId];
        delete tokenResetAddress[tokenId];
    }

    // Internal function to remove an element from an array uint256.
    function removeElement(uint256[] storage array, uint256 element) internal {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                array[i] = array[array.length - 1];
                array.pop();
                return;
            }
        }
    }

    // Internal function to remove an element from an array address.
    function removeElementAddress(address[] storage array, address element) internal {
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

    // Internal function to check if an element exists in an array.
    function containsAddress(address[] storage array, address element) internal view returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return true;
            }
        }
        return false;
    }

    // function isOnPoint(euint32 lat, euint32 lng, Location memory location) internal view returns (bool) {
    //     ebool isLatSouth = TFHE.ge(lat, location.southLat);
    //     ebool isLatNorth = TFHE.le(lat, location.northLat);

    //     euint8 isErrorLatSouth = TFHE.cmux(isLatSouth, NO_ERROR, ERROR);
    //     euint8 isErrorLatNorth = TFHE.cmux(isLatNorth, NO_ERROR, ERROR);

    //     ebool isLngWest = TFHE.ge(lng, location.westLon);
    //     ebool isLngEast = TFHE.le(lng, location.eastLon);
    //     euint8 isErrorLngWest = TFHE.cmux(isLngWest, NO_ERROR, ERROR);
    //     euint8 isErrorLngEast = TFHE.cmux(isLngEast, NO_ERROR, ERROR);

    //     euint8 sumLat = TFHE.add(isErrorLatSouth, isErrorLatNorth);
    //     euint8 sumLng = TFHE.add(isErrorLngWest, isErrorLngEast);

    //     euint8 sumGlobal = TFHE.add(sumLat, sumLng);

    //     return TFHE.decrypt(TFHE.eq(sumGlobal, NO_ERROR));
    // }

    /************************ GAMING FUNCTIONS *************************/

    /**
     * @dev createGPS one or more NFTs, with tax (one round) just for owner smart contract. set on 0
     * @param data An array of NFT GPS coordinates to be create.
     * @param feesData An array of fees to be create corresponding of array data.
     */
    function createGpsOwner(bytes[] calldata data, uint256[] calldata feesData) external onlyOwner {
        mint(data, address(this), feesData);
    }

    /**
     * @dev createGPS one or more NFTs, with tax (one round) just for owner nft.
     * @param data An array of NFT GPS coordinates to be create.
     * @param feesData An array of fees to be create corresponding of array data.
     */
    function createGpsOwnerNft(bytes[] calldata data, uint256[] calldata feesData) external isAccess {
        transactionCoinSpace();
        distributeFeesToCreators();
        uint256 mintAmount = amountMintErc20 * (10 ** 18);

        coinSpace.mint(address(this), mintAmount);
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
            tokenStakeAddress[nftId] = msg.sender;
            _transfer(ownerOf(nftId), address(this), nftId);

            if (stakeNft[msg.sender].length >= 1) {
                stakersRewards[msg.sender] = true;
            }
            emit StakingNFT(msg.sender, nftId, block.timestamp, true);
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

            isStake[nftId] = false;
            delete tokenStakeAddress[nftId];
            if (stakeNft[msg.sender].length < 1) {
                removeElementAddress(stakerReward, msg.sender);
                delete stakersRewards[msg.sender];
            }

            _transfer(ownerOf(nftId), msg.sender, nftId);
            emit StakingNFT(msg.sender, nftId, block.timestamp, false);
        }
    }

    // function isOnPoint(euint32 lat, euint32 lng, Location memory location) internal view returns (bool) {
    //     return (TFHE.decrypt(TFHE.ge(lat, location.southLat)) &&
    //         TFHE.decrypt(TFHE.le(lat, location.northLat)) &&
    //         TFHE.decrypt(TFHE.ge(lng, location.westLon)) &&
    //         TFHE.decrypt(TFHE.le(lng, location.eastLon)));
    // }

    function isOnPoint(euint32 lat, euint32 lng, Location memory location) internal view returns (bool) {
        ebool isLatSouth = TFHE.ge(lat, location.southLat);
        ebool isLatNorth = TFHE.le(lat, location.northLat);

        euint8 isErrorLatSouth = TFHE.cmux(isLatSouth, NO_ERROR, ERROR);
        euint8 isErrorLatNorth = TFHE.cmux(isLatNorth, NO_ERROR, ERROR);

        ebool isLngWest = TFHE.ge(lng, location.westLon);
        ebool isLngEast = TFHE.le(lng, location.eastLon);
        euint8 isErrorLngWest = TFHE.cmux(isLngWest, NO_ERROR, ERROR);
        euint8 isErrorLngEast = TFHE.cmux(isLngEast, NO_ERROR, ERROR);

        euint8 sumLat = TFHE.add(isErrorLatSouth, isErrorLatNorth);
        euint8 sumLng = TFHE.add(isErrorLngWest, isErrorLngEast);

        euint8 sumGlobal = TFHE.add(sumLat, sumLng);

        return TFHE.decrypt(TFHE.eq(sumGlobal, NO_ERROR));
    }

    // A TESTER ENCORE CAR LE RESULTAT N'EST PAS CELUI VOULUS
    // function isOnPoint(euint32 lat, euint32 lng, Location memory location) internal view returns (uint8) {
    //     ebool isLatSouth = TFHE.ge(lat, location.southLat);
    //     ebool isLatNorth = TFHE.le(lat, location.northLat);

    //     euint8 isErrorLatSouth = TFHE.cmux(isLatSouth, NO_ERROR, ERROR);
    //     euint8 isErrorLatNorth = TFHE.cmux(isLatNorth, NO_ERROR, ERROR);

    //     ebool isLngWest = TFHE.ge(lng, location.westLon);
    //     ebool isLngEast = TFHE.le(lng, location.eastLon);
    //     euint8 isErrorLngWest = TFHE.cmux(isLngWest, NO_ERROR, ERROR);
    //     euint8 isErrorLngEast = TFHE.cmux(isLngEast, NO_ERROR, ERROR);

    //     euint8 compareLat = TFHE.and(isErrorLatSouth, isErrorLatNorth);
    //     euint8 compareLng = TFHE.and(isErrorLngWest, isErrorLngEast);

    //     return TFHE.decrypt(TFHE.and(compareLat, compareLng));
    // }

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

        bool isWin = false;
        uint256 totalSupply = totalSupply();

        require(_tokenId <= totalSupply, "Your token id is invalid");
        require(isLocationValid(_tokenId), "Location does not valid");
        if (isOnPoint(lat, lng, locations[_tokenId])) {
            //if (TFHE.decrypt(TFHE.eq(isOnPoint(lat, lng, locations[_tokenId]), NO_ERROR))) {
            require(ownerOf(_tokenId) != msg.sender, "you are the owner");
            require(!isStake[_tokenId], "NFT is stake"); // prevent
            require(getAddressCreationWithToken(_tokenId) != msg.sender, "you are the creator !");

            address actualOwner = ownerNft[_tokenId];
            require(actualOwner != msg.sender, "you are the owner !"); // prevent

            uint256 missingFunds = checkFees(_tokenId, actualOwner);
            require(missingFunds == 0, string(abi.encodePacked("Insufficient funds. Missing ", missingFunds, " wei")));

            payable(actualOwner).transfer(userFees[actualOwner][_tokenId]); // msg.sender transfer fees to actual owner of nft.

            resetMapping(_tokenId, actualOwner); // Reset data with delete
            removeElement(resetNft[actualOwner], _tokenId); // delete resetOwner from array mapping
            ownerNft[_tokenId] = msg.sender; // Allows recording the new owner for the reset (NFTs back in game).
            isWin = true;

            rewardUserWithERC20(msg.sender, amountRewardUser); //reward token SpaceCoin to user
            _transfer(ownerOf(_tokenId), msg.sender, _tokenId); //Transfer nft to winner
        }

        emit GpsCheckResult(msg.sender, isWin, _tokenId);
        return isWin;
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
            ownerNft[tokenId] = ownerOf(tokenId);
            locations[tokenId].isValid = true;
            tokenResetAddress[tokenId] = msg.sender;

            _transfer(msg.sender, address(this), tokenId);
            emit ResetNFT(msg.sender, tokenId, true, tax);
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
            require(!contains(creatorNft[msg.sender], tokenId), "the creator cannot cancel reset nft");

            locations[tokenId].isValid = false;
            delete tokenResetAddress[tokenId];
            userFees[msg.sender][tokenId] = 0;

            removeElement(resetNft[msg.sender], tokenId);
            _transfer(address(this), msg.sender, tokenId);
            emit ResetNFT(msg.sender, tokenId, false, 0);
        }
    }

    /**
     * @dev brun nft with id, reset mapping, delete location and all creations ids and address
     * @param tokenId An array of NFT IDs to cancel the reset for.
     */
    function burnNFT(uint256 tokenId) external onlyOwner {
        address actualOwner = ownerNft[tokenId];

        resetMapping(tokenId, actualOwner);
        delete locations[tokenId];
        delete creatorNft[actualOwner];
        delete tokenCreationAddress[tokenId];
        delete isStake[tokenId];

        _burn(tokenId);
    }
}
