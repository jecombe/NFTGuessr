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
import "./airdrop/AirDrop.sol";
import "./Lib.sol";

contract NftGuessr is ERC721Enumerable, Ownable, EIP712WithModifier {
    /* LIBRARIES */
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private _tokenIdCounter; // tokenCounter id NFT
    string private _baseTokenURI; // Don't use actually
    address public contractOwner;

    /* CREATOR */
    address[] public creatorNftAddresses; //  Save all address creators of NFT GeoSpace, can be add, but can't remove element

    AirDrop private airdrop;
    uint256 public counterGuess = 0;
    /* FEES */
    uint256 public fees = 2 ether; // Fees (Zama) base
    uint256 public feesCreation = 1; // Fees (SPC) nft creation Geospace
    uint256 public feesRewardCreator = 1;
    /* ERC20 */
    CoinSpace private coinSpace; // CoinSpace interface token Erc20
    uint256 public amountRewardUser = 1; // amount reward winner
    /* MAPPING */
    mapping(uint256 => Location) internal locations; // Mapping to store NFT locations and non-accessible locations.
    mapping(address => uint256[]) public creatorNft; // To see all NFTsIDs back in game
    mapping(address => mapping(uint256 => uint256)) public userFees; // To see all fees for nfts address user
    mapping(uint256 => address) ownerNft; // This variable is used to indirectly determine if a user is the owner of the NFT.
    mapping(uint256 => address) public tokenResetAddress; //  See address user NFT back in game with ID
    mapping(uint256 => address) public tokenCreationAddress; // See address user NFT creation with ID
    mapping(address => uint256[]) public resetNft; // To see all NFTsIDs back in game
    mapping(address => uint[]) winners;
    mapping(address => uint256) public balanceRewardStaker;
    mapping(address => uint256) public balanceRewardCreator;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public lastStakeUpdateTime;
    uint256 public balanceTeams = 0;
    address[] stakers;
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    /* EVENT */
    event GpsCheckResult(address indexed user, bool result, uint256 tokenId); // Event emitted when a user checks the GPS coordinates against an NFT location.
    event createNFT(address indexed user, uint256 tokenId, uint256 fee); // Event emitted when a new NFT is created.
    event ResetNFT(address indexed user, uint256 tokenId, bool isReset, uint256 tax); // Event emitted when an NFT is reset.
    event RewardWithERC20(address indexed user, uint256 amount); // Event to see when user receive reward token.

    // Contract constructor initializes base token URI and owner.
    constructor() ERC721("GeoSpace", "GSP") EIP712WithModifier("Authorization token", "1") {
        _baseTokenURI = "";
        contractOwner = msg.sender;
    }

    /************************ MODIFER FUNCTIONS *************************/

    // Check if user have access
    modifier isAccess() {
        require(getNFTsResetByOwner(msg.sender).length >= 1, "The creator must back in game minimum 1 NFTs");
        _;
    }

    function getBalanceStake(address _player) public view returns (uint256) {
        return stakedBalance[_player];
    }

    function stakeSPC(uint256 amount) external {
        require(amount > 0, "cannot stake with 0 token");

        require(coinSpace.allowance(msg.sender, address(this)) >= amount, "echec allowance");

        if (stakedBalance[msg.sender] == 0) {
            stakers.push(msg.sender);
        }

        // Transférer les jetons du joueur au contrat
        require(coinSpace.transferFrom(msg.sender, address(this), amount), "echec");

        // Mettre à jour les variables de mise en jeu
        stakedBalance[msg.sender] = stakedBalance[msg.sender].add(amount);

        emit Staked(msg.sender, amount);
    }

    function unstakeSPC(uint256 amount) external {
        require(amount > 0, "nothing to unstake");
        require(amount <= stakedBalance[msg.sender], "amount > balance stake");

        // Mettre à jour les variables de staking
        stakedBalance[msg.sender] = stakedBalance[msg.sender].sub(amount);
        // lastStakeTime[msg.sender] = block.timestamp;
        coinSpace.transfer(msg.sender, amount); // Ajouter rewards si nécessaire

        emit Withdrawn(msg.sender, amount);
    }

    /************************ OWNER FUNCTIONS *************************/

    // Change tokenAddress Erc20
    function setAddressToken(address _tokenErc20) external onlyOwner {
        coinSpace = CoinSpace(_tokenErc20);
    }

    function setAddressAirdropToken(address _airdrop, address _token) external onlyOwner {
        airdrop = AirDrop(_airdrop);
        airdrop.setAddressToken(_token);
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
    function getNFTLocation(uint256 tokenId, bytes32 publicKey) external view onlyOwner returns (NFTLocation memory) {
        return getLocation(locations[tokenId], publicKey);
    }

    // Function to get the location of an NFT for owner using decrypted coordinates.
    function getNFTLocationForOwner(
        uint256 tokenId,
        bytes32 publicKey,
        bytes calldata signature
    ) external view onlySignedPublicKey(publicKey, signature) returns (NFTLocation memory) {
        address resetAddr = getAddressResetWithToken(tokenId); // Check if user is reset (back in game) nft
        address creaAddr = getAddressCreationWithToken(tokenId); // Check if user is the creator

        if (ownerOf(tokenId) == msg.sender) {
            return getLocation(locations[tokenId], publicKey);
        } else if (resetAddr == msg.sender || creaAddr == msg.sender) {
            return getLocation(locations[tokenId], publicKey);
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

    // Function to get the fee associated with a user and an NFT.
    function getFee(address user, uint256 id) external view returns (uint256) {
        return userFees[user][id];
    }

    function getBalanceRewardStaker(address user) external view returns (uint256) {
        return balanceRewardStaker[user];
    }

    function getBalanceRewardCreator(address user) external view returns (uint256) {
        return balanceRewardCreator[user];
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

    function getNftWinnerForUser(address user) public view returns (uint256[] memory) {
        return winners[user];
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

    function distributeFeesToCreators() internal {
        uint256 totalCreators = creatorNftAddresses.length;
        if (totalCreators > 0 && feesRewardCreator > 0) {
            uint256 totalNft = getTotalNft();

            for (uint256 i = 0; i < totalCreators; i++) {
                address creator = creatorNftAddresses[i];

                if (creator != msg.sender && creator != contractOwner) {
                    uint256 ratio = creatorNft[msg.sender].length.mul(10 ** 18).div(totalNft);
                    uint256 feeShare = feesRewardCreator.mul(ratio).div(10 ** 18);
                    balanceRewardCreator[creator] += feeShare;
                }
            }
        }
    }
    // Internal function to get strcture result get Location decrypt
    function getLocation(Location memory _location, bytes32 publicKey) internal view returns (NFTLocation memory) {
        bytes memory lat = TFHE.reencrypt(_location.lat, publicKey, 0);
        bytes memory lng = TFHE.reencrypt(_location.lng, publicKey, 0);
        return NFTLocation(lat, lng);
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
            emit createNFT(msg.sender, tokenId, feesData[i]);
        }
    }

    // Internal function to reward the user with ERC-20 tokens
    function rewardUserWithERC20(address user, uint256 amountReward) internal {
        uint256 mintAmount = amountReward.mul(10 ** 18);

        coinSpace.mint(user, mintAmount);
        // balanceRewardCreator[user] += mintAmount;

        emit RewardWithERC20(user, mintAmount);
    }

    // Internal function to create transaction from msg.sender to smart contract
    function transactionCoinSpace() internal {
        uint256 amountToTransfer = feesCreation.mul(10 ** 18);

        require(getBalanceCoinSpace(msg.sender) >= amountToTransfer, "Insufficient ERC-20 balance");
        coinSpace.burn(amountToTransfer, msg.sender);
    }

    /************************ INTERNAL FUNCTIONS UTILS *************************/

    // Internal function to reset mapping
    function resetMapping(uint256 tokenId, address _ownerNft) internal {
        delete userFees[_ownerNft][tokenId];
        locations[tokenId].isValid = false;
        delete ownerNft[tokenId];
        delete tokenResetAddress[tokenId];
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

    // Internal function to check if an element exists in an array.
    function containsAddress(address[] storage array, address element) internal view returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return true;
            }
        }
        return false;
    }

    // Internal function to check if user in on nft radius.
    function isOnPoint(euint32 lat, euint32 lng, Location memory location) internal view returns (bool) {
        ebool isLatSouth = TFHE.ge(lat, location.southLat); //if lat >= location.southLat => true if correct
        ebool isLatNorth = TFHE.le(lat, location.northLat); // if lat <= location.northLat => true if correct
        ebool isLatValid = TFHE.and(isLatSouth, isLatNorth);

        ebool isLngWest = TFHE.ge(lng, location.westLon); // true if correct
        ebool isLngEast = TFHE.le(lng, location.eastLon); // true if correct
        ebool isLngValid = TFHE.and(isLngWest, isLngEast);

        return TFHE.decrypt(TFHE.and(isLngValid, isLatValid)); // Check if lat AND long are valid
    }

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
        // distributeFeesToCreators();
        //  uint256 mintAmount = amountMintErc20 * (10 ** 18);

        //  coinSpace.mint(address(this), mintAmount);
        mint(data, address(this), feesData);
    }

    function rewardStakers() internal {
        if (stakers.length <= 0) return;

        uint256 rewardForStaker = 1 ether;

        // Calculate total staked amount
        uint256 totalStakedAmount = 0;
        for (uint256 i = 0; i < stakers.length; i++) {
            totalStakedAmount = totalStakedAmount.add(stakedBalance[stakers[i]]);
        }

        // Distribute rewards based on staking ratio
        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 stakerBalance = stakedBalance[staker];

            if (stakerBalance > 0) {
                // Calculate staker's ratio
                uint256 stakerRatio = stakerBalance.mul(10 ** 18).div(totalStakedAmount);

                // Calculate reward for the staker based on their ratio
                uint256 stakerReward = rewardForStaker.mul(stakerRatio).div(10 ** 18);
                balanceRewardStaker[staker] = balanceRewardStaker[staker].add(stakerReward);
                // Transfer the reward in Ether to the staker
                // (bool success, ) = staker.call{ value: stakerReward }("");
                // require(success, "Reward transfer failed");
                // Transfer the reward to the staker
                //rewardUserWithERC20(staker, stakerReward);
            }
        }
    }

    function rewardTeams() internal {
        uint256 rewardForOwner = 1 ether;
        balanceTeams = balanceTeams.add(rewardForOwner);
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

        bool isWin = false;
        uint256 totalSupply = totalSupply();

        require(_tokenId <= totalSupply, "Your token id is invalid");
        require(isLocationValid(_tokenId), "Location does not valid");
        require(ownerOf(_tokenId) != msg.sender, "you are the owner");
        require(getAddressCreationWithToken(_tokenId) != msg.sender, "you are the creator !");
        require(!isWinner(msg.sender, _tokenId), "You have already won this NFT.");

        address actualOwner = ownerNft[_tokenId];
        require(actualOwner != msg.sender, "you are the owner !"); // prevent

        uint256 missingFunds = checkFees(_tokenId, actualOwner);
        require(missingFunds == 0, string(abi.encodePacked("Insufficient funds. Missing ", missingFunds, " wei")));

        payable(actualOwner).transfer(userFees[actualOwner][_tokenId]); // msg.sender transfer fees to actual owner of nft.

        if (isOnPoint(lat, lng, locations[_tokenId])) {
            resetMapping(_tokenId, actualOwner); // Reset data with delete
            Lib.removeElement(resetNft[actualOwner], _tokenId); // delete resetOwner from array mapping
            ownerNft[_tokenId] = msg.sender; // Allows recording the new owner for the reset (NFTs back in game).
            isWin = true;
            winners[msg.sender].push(_tokenId);
            rewardUserWithERC20(msg.sender, amountRewardUser); //reward token SpaceCoin to user
            _transfer(ownerOf(_tokenId), msg.sender, _tokenId); //Transfer nft to winner
        }
        counterGuess += 1;
        rewardStakers();
        rewardTeams();
        distributeFeesToCreators();
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
            require(!Lib.contains(resetNft[msg.sender], tokenId), "NFT is already back in game");
            require(!Lib.contains(creatorNft[msg.sender], tokenId), "the creator cannot reset nft");

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

            require(Lib.contains(resetNft[msg.sender], tokenId), "NFT is not back in game");
            require(!Lib.contains(creatorNft[msg.sender], tokenId), "the creator cannot cancel reset nft");

            locations[tokenId].isValid = false;
            delete tokenResetAddress[tokenId];
            userFees[msg.sender][tokenId] = 0;

            Lib.removeElement(resetNft[msg.sender], tokenId);
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
        _burn(tokenId);
    }

    function claimRewardStaker() public {
        require(balanceRewardStaker[msg.sender] > 0, "your balance is Zero");
        (bool success, ) = msg.sender.call{ value: balanceRewardStaker[msg.sender] }("");
        require(success, "Reward transfer failed");
    }

    function claimRewardCreator() public {
        require(balanceRewardCreator[msg.sender] > 0, "your balance is Zero");

        coinSpace.mint(msg.sender, balanceRewardCreator[msg.sender]);
    }

    function claimRewardTeams() public onlyOwner {
        require(balanceTeams > 0, "your balance is Zero");
        (bool success, ) = msg.sender.call{ value: balanceTeams }("");
        require(success, "Reward transfer failed");
    }

    function claimAirDrop() public {
        airdrop.claimTokens(msg.sender, winners[msg.sender].length, creatorNft[msg.sender].length);
    }

    function estimateRewardPlayer() public {
        airdrop.estimateRewards(msg.sender, winners[msg.sender].length, creatorNft[msg.sender].length);
    }

    function setDistribution() public {
        airdrop.setDistributions();
    }
}
