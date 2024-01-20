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

import "./libraries/Lib.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NftGuessr is Ownable, ReentrancyGuard {
    /* LIBRARIES */
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    Counters.Counter private _tokenIdCounter; // tokenCounter id NFT
    Counters.Counter private counterGuess;
    Counters.Counter private counterCreatorPlayers;

    EnumerableSet.AddressSet private creatorNftAddresses;

    string private _baseTokenURI; // Don't use actually
    address public contractOwner;
    uint256 public fees = 2 ether; // Fees (Zama) base
    uint256 public feesCreation = 1; // Fees (SPC) nft creation Geospace
    uint256 public feesRewardCreator = 1;
    uint256 public amountRewardUser = 1; // amount reward winner
    uint256 public balanceTeams = 0;
    address[] stakers;

    CoinSpace private coinSpace; // CoinSpace interface token Erc20
    Game private game;
    AirDrop private airdrop;

    mapping(address => uint256) public balanceRewardStaker;
    mapping(address => uint256) public balanceRewardCreator;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public lastStakeUpdateTime;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    /* EVENT */
    event GpsCheckResult(address indexed user, bool result, uint256 tokenId); // Event emitted when a user checks the GPS coordinates against an NFT location.
    event createNFT(address indexed user, uint256 tokenId, uint256 fee); // Event emitted when a new NFT is created.
    event ResetNFT(address indexed user, uint256 tokenId, bool isReset, uint256 tax); // Event emitted when an NFT is reset.
    event RewardWithERC20(address indexed user, uint256 amount); // Event to see when user receive reward token.

    // Contract constructor initializes base token URI and owner.
    constructor() {
        _baseTokenURI = "";
        contractOwner = msg.sender;
    }

    /************************ MODIFER FUNCTIONS *************************/

    // Check if user have access
    modifier isAccess() {
        require(game.getNFTsResetByOwner(msg.sender).length >= 1, "The creator must back in game minimum 1 NFTs");
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
        require(amount > 0);
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

    function setAddressGame(address _game) external onlyOwner {
        game = Game(_game);
    }

    function setAddressAirdropToken(address _airdrop, address _token) external onlyOwner {
        airdrop = AirDrop(_airdrop);
        airdrop.setAddressToken(_token);
    }

    function setDistribution() external onlyOwner {
        airdrop.setDistributions();
    }
    /************************ FALLBACK FUNCTIONS *************************/

    // Fallback function to receive Ether.
    receive() external payable {}

    /************************ GETTER FUNCTIONS *************************/

    //get balance user SPC
    function getBalanceCoinSpace(address user) public view returns (uint256) {
        return coinSpace.balanceOf(user);
    }

    function getBalanceRewardStaker(address user) external view returns (uint256) {
        return balanceRewardStaker[user];
    }

    function getBalanceRewardCreator(address user) external view returns (uint256) {
        return balanceRewardCreator[user];
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

    function distributeFeesToCreators() internal {
        uint256 totalCreators = creatorNftAddresses.length();
        if (totalCreators > 0 && feesRewardCreator > 0) {
            uint256 totalNft = game.getTotalNft();

            for (uint256 i = 0; i < totalCreators; i++) {
                address creator = creatorNftAddresses.at(i);

                if (creator != msg.sender && creator != contractOwner) {
                    uint256 ratio = game.getIdCreator(msg.sender).length.mul(10 ** 18).div(totalNft);
                    uint256 feeShare = feesRewardCreator.mul(ratio).div(10 ** 18);
                    balanceRewardCreator[creator] = balanceRewardCreator[creator].add(feeShare);
                }
            }
        }
    }

    // Internal function to check if user has enough funds to pay NFT tax.
    function checkFees(uint256 _tokenId, address _ownerNft) internal view returns (uint256) {
        uint256 nftFees = game.getFee(_ownerNft, _tokenId);
        uint256 totalTax = fees.add(nftFees);

        if (msg.value >= totalTax) {
            return 0; // fees enough
        } else {
            return totalTax.sub(msg.value); //fees need
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

    /************************ GAMING FUNCTIONS *************************/

    /**
     * @dev createGPS one or more NFTs, with tax (one round) just for owner smart contract. set on 0
     * @param data An array of NFT GPS coordinates to be create.
     * @param feesData An array of fees to be create corresponding of array data.
     */
    function createGpsOwner(bytes[] calldata data, uint256[] calldata feesData) external onlyOwner {
        require(data.length >= 6);

        uint256 arrayLength = data.length.div(6);

        for (uint256 i = 0; i < arrayLength; i++) {
            uint256 baseIndex = i.mul(6);
            uint256 tokenId = game.mint(msg.sender, data, feesData[i], baseIndex);
            emit createNFT(msg.sender, tokenId, feesData[i]);
        }
    }

    /**
     * @dev createGPS one or more NFTs, with tax (one round) just for owner nft.
     * @param data An array of NFT GPS coordinates to be create.
     * @param feesData An array of fees to be create corresponding of array data.
     */
    function createGpsOwnerNft(bytes[] calldata data, uint256[] calldata feesData) external isAccess {
        transactionCoinSpace();
        require(data.length >= 6);

        uint256 arrayLength = data.length.div(6);

        for (uint256 i = 0; i < arrayLength; i++) {
            uint256 baseIndex = i.mul(6);
            uint256 tokenId = game.mint(msg.sender, data, feesData[i], baseIndex);
            counterCreatorPlayers.increment();
            emit createNFT(msg.sender, tokenId, feesData[i]);
        }
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
     */
    function checkGps(bytes calldata userLatitude, bytes calldata userLongitude, uint256 _tokenId) external payable {
        require(
            msg.value >= fees,
            string(abi.encodePacked("Insufficient fees. A minimum of ", fees, " ZAMA is required."))
        );

        // address actualOwner = ownerNft[_tokenId];
        address actualOwner = game.getActualOwner(_tokenId);

        uint256 missingFunds = checkFees(_tokenId, actualOwner);
        require(missingFunds == 0, string(abi.encodePacked("Insufficient funds. Missing ", missingFunds, " wei")));
        bool isWin = game.checkGps(msg.sender, userLatitude, userLongitude, _tokenId);

        if (isWin) {
            rewardUserWithERC20(msg.sender, amountRewardUser); //reward token SpaceCoin to user
        }
        payable(actualOwner).transfer(game.getFee(actualOwner, _tokenId)); // msg.sender transfer fees to actual owner of nft.
        counterGuess.increment();
        rewardStakers();
        rewardTeams();
        distributeFeesToCreators();
        emit GpsCheckResult(msg.sender, isWin, _tokenId);
    }

    /**
     * @dev Resets one or more NFTs, putting them back into the game.
     * @param tokenIds An array of NFT IDs to be reset.
     * @param taxes An array of corresponding taxes for each NFT to be reset.
     */
    function resetNFT(uint256[] calldata tokenIds, uint256[] calldata taxes) external {
        require(tokenIds.length > 0);
        require(tokenIds.length == taxes.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            game.resetNFT(msg.sender, tokenIds[i], taxes[i]);
            emit ResetNFT(msg.sender, tokenIds[i], true, taxes[i]);
        }
    }

    /**
     * @dev Cancels the reset of one or more NFTs.
     * @param tokenIds An array of NFT IDs to cancel the reset for.
     */
    function cancelResetNFT(uint256[] calldata tokenIds) external {
        require(tokenIds.length > 0, "No token IDs provided");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            game.cancelResetNFT(msg.sender, tokenIds[i]);
            emit ResetNFT(msg.sender, tokenIds[i], false, 0);
        }
    }

    function claimRewardStaker() external nonReentrant {
        require(balanceRewardStaker[msg.sender] > 0, "your balance is Zero");
        balanceRewardStaker[msg.sender] = 0;
        (bool success, ) = msg.sender.call{ value: balanceRewardStaker[msg.sender] }("");
        require(success, "Reward transfer failed");
    }

    function claimRewardCreator() external nonReentrant {
        require(balanceRewardCreator[msg.sender] > 0, "your balance is Zero");
        balanceRewardCreator[msg.sender] = 0;
        coinSpace.mint(msg.sender, balanceRewardCreator[msg.sender]);
    }

    function claimRewardTeams() external onlyOwner nonReentrant {
        require(balanceTeams > 0, "your balance is Zero");
        balanceTeams = 0;
        (bool success, ) = msg.sender.call{ value: balanceTeams }("");
        require(success, "Reward transfer failed");
    }

    function claimAirDrop() external nonReentrant {
        airdrop.claimTokens(
            msg.sender,
            game.getNftWinnerForUser(msg.sender).length,
            game.getIdCreator(msg.sender).length
        );
    }

    function claimAirDropTeams() external nonReentrant {
        airdrop.claimTeamsTokens(msg.sender, counterGuess.current(), counterCreatorPlayers.current());
    }

    function estimateRewardPlayer() external {
        airdrop.estimateRewards(
            msg.sender,
            game.getNftWinnerForUser(msg.sender).length,
            game.getIdCreator(msg.sender).length
        );
    }

    function estimateRewardTeams() external {
        airdrop.estimateRewardTeams(msg.sender, counterGuess.current(), counterCreatorPlayers.current());
    }
}
