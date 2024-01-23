// @title NftGuessr - Smart contract for a location-based NFT guessing game.
// @author [Jérémy Combe]
// @notice This contract extends ERC721Enumerable for NFT functionality.
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./libraries/Lib.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NftGuessr is Ownable, ReentrancyGuard {
    /* LIBRARIES */
    using Counters for Counters.Counter;
    using SafeMath for uint;
    using EnumerableSet for EnumerableSet.AddressSet;

    Counters.Counter public counterGuess;
    Counters.Counter public counterCreatorPlayers;

    EnumerableSet.AddressSet private creatorNftAddresses;
    EnumerableSet.AddressSet private stakersSpcAddresses;

    uint public totalStakedAmount;
    string private _baseTokenURI; // Don't use actually
    address public contractOwner;
    uint public fees = 2 ether; // Fees (Zama) base
    uint public rewardFeesStakers = 1 ether;
    uint public rewardFeesTeams = 1 ether;

    uint public feesCreation = 1; // Fees (SPC) nft creation Geospace
    uint public feesRewardCreator = 1;
    uint public amountRewardUser = 1; // amount reward winner
    uint public balanceTeams = 0;
    uint public rewardPercentageCreator = 3;
    mapping(uint => uint) public winningFees;

    SpaceCoin private coinSpace; // CoinSpace interface token Erc20
    GeoSpace private game;
    AirDrop private airdrop;

    mapping(address => uint) public balanceRewardStaker;
    mapping(address => uint) public balanceRewardCreator;
    mapping(address => uint) public balanceRewardOwner; // change to balanceRewardOwner;
    mapping(address => uint) public stakedBalance;
    mapping(address => uint) public lastStakeUpdateTime;
    mapping(address => uint) public ratioRewardStaker;
    mapping(address => uint) public ratioRewardCreator;

    /* EVENT */
    event Staked(address indexed user, uint amount);
    event Withdrawn(address indexed user, uint amount);
    event GpsCheckResult(address indexed user, bool result, uint tokenId); // Event emitted when a user checks the GPS coordinates against an NFT location.
    event createNFT(address indexed user, uint tokenId, uint fee); // Event emitted when a new NFT is created.
    event ResetNFT(address indexed user, uint tokenId, bool isReset, uint tax); // Event emitted when an NFT is reset.
    event RewardWinner(address indexed user, uint amount, uint tokenId); // Event to see when user receive reward token.
    event RewardCreators(address indexed user, uint amountReward, uint tokenId); // Event to see when user receive reward token.
    event RewardCreatorFees(address indexed user, uint amountReward, uint tokenId); // Event to see when user receive reward token.
    event RewardOwnerFees(address indexed user, uint amountReward, uint tokenId);
    event RewardStakers(address indexed user, uint amountReward, uint tokenId); // Event to see when user receive reward token.
    event RewardTeams(address indexed user, uint amountReward, uint balance, uint tokenId); // Event to see when user receive reward token.

    // Contract constructor initializes base token URI and owner.
    constructor() {
        _baseTokenURI = "";
        contractOwner = msg.sender;
    }

    receive() external payable {}

    /************************ MODIFER FUNCTIONS *************************/

    // Check if user have access
    modifier isAccess() {
        require(game.getNFTsResetByOwner(msg.sender).length >= 1, "The creator must back in game minimum 1 NFTs");
        _;
    }

    /************************ GAMING FUNCTIONS *************************/

    /**
     * @dev createGPS one or more NFTs, with tax (one round) just for owner smart contract. set on 0
     * @param data An array of NFT GPS coordinates to be create.
     * @param feesData An array of fees to be create corresponding of array data.
     */
    function createGpsOwner(bytes[] calldata data, uint[] calldata feesData) external onlyOwner {
        require(data.length >= 6);

        uint arrayLength = data.length.div(6);

        for (uint i = 0; i < arrayLength; i++) {
            uint baseIndex = i.mul(6);

            uint tokenId = game.mint(msg.sender, data, feesData[i], baseIndex);
            winningFees[tokenId] = feesData[i];

            emit createNFT(msg.sender, tokenId, feesData[i]);
        }
    }

    /**
     * @dev createGPS one or more NFTs, with tax (one round) just for owner nft.
     * @param data An array of NFT GPS coordinates to be create.
     * @param feesData An array of fees to be create corresponding of array data.
     */
    function createGpsOwnerNft(bytes[] calldata data, uint[] calldata feesData) external isAccess {
        transactionCoinSpace();
        require(data.length >= 6);

        uint arrayLength = data.length.div(6);

        for (uint i = 0; i < arrayLength; i++) {
            uint baseIndex = i.mul(6);

            require(game.lifePointTotal(msg.sender) > 0, "your life points mint is over");
            if (!creatorNftAddresses.contains(msg.sender)) {
                creatorNftAddresses.add(msg.sender);
            }
            counterCreatorPlayers.increment();
            game.subLifePoint(msg.sender);
            uint tokenId = game.mint(msg.sender, data, feesData[i], baseIndex);
            winningFees[tokenId] = feesData[i];

            emit createNFT(msg.sender, tokenId, feesData[i]);
        }
    }

    /**
     * @dev Checks GPS coordinates against a specified location's coordinates.
     * @param userLatitude The latitude of the user's location.
     * @param userLongitude The longitude of the user's location.
     * @param _tokenId The ID of the NFT being checked.
     */
    function checkGps(
        bytes calldata userLatitude,
        bytes calldata userLongitude,
        uint _tokenId
    ) external payable nonReentrant {
        uint calculTotalFees = fees.add(winningFees[_tokenId]);

        require(
            msg.value >= calculTotalFees,
            string(abi.encodePacked("Insufficient fees. A minimum of ", calculTotalFees, " ZAMA is required."))
        );

        address actualOwner = game.ownerNft(_tokenId);

        bool isWin = game.checkGps(msg.sender, userLatitude, userLongitude, _tokenId);
        counterGuess.increment();
        rewardStakersSpc(_tokenId);
        rewardTeams(_tokenId);
        rewardCreatorsGsp(_tokenId);
        if (isWin) {
            rewardSpaceCoinPlayer(msg.sender, amountRewardUser, _tokenId); //reward token SpaceCoin to user
            rewardCreatorAndOwner(actualOwner, _tokenId);
            winningFees[_tokenId] = 0;
        } else {
            refundPlayer(msg.sender, _tokenId);
        }
        emit GpsCheckResult(msg.sender, isWin, _tokenId);
    }

    /**
     * @dev Resets one or more NFTs, putting them back into the game.
     * @param tokenIds An array of NFT IDs to be reset.
     * @param taxes An array of corresponding taxes for each NFT to be reset.
     */
    function resetNFT(uint[] calldata tokenIds, uint[] calldata taxes) external {
        require(tokenIds.length > 0);
        require(tokenIds.length == taxes.length);

        for (uint i = 0; i < tokenIds.length; i++) {
            game.resetNFT(msg.sender, tokenIds[i], taxes[i]);
            winningFees[tokenIds[i]] = taxes[i];
            emit ResetNFT(msg.sender, tokenIds[i], true, taxes[i]);
        }
    }

    /**
     * @dev Cancels the reset of one or more NFTs.
     * @param tokenIds An array of NFT IDs to cancel the reset for.
     */
    function cancelResetNFT(uint[] calldata tokenIds) external {
        require(tokenIds.length > 0, "No token IDs provided");

        for (uint i = 0; i < tokenIds.length; i++) {
            game.cancelResetNFT(msg.sender, tokenIds[i]);
            emit ResetNFT(msg.sender, tokenIds[i], false, 0);
        }
    }

    /************************ COINS FUNCTIONS *************************/

    function stakeSPC(uint amount) external {
        require(amount > 0, "cannot stake with 0 token");

        require(coinSpace.allowance(msg.sender, address(this)) >= amount, "echec allowance");

        if (stakedBalance[msg.sender] == 0 && !stakersSpcAddresses.contains(msg.sender)) {
            stakersSpcAddresses.add(msg.sender);
        }
        stakedBalance[msg.sender] = stakedBalance[msg.sender].add(amount);
        totalStakedAmount = totalStakedAmount.add(amount);

        require(coinSpace.transferFrom(msg.sender, address(this), amount), "echec");

        emit Staked(msg.sender, amount);
    }

    function unstakeSPC(uint amount) external {
        require(amount > 0);
        require(amount <= stakedBalance[msg.sender], "amount > balance stake");

        stakedBalance[msg.sender] = stakedBalance[msg.sender].sub(amount);
        if (stakedBalance[msg.sender] == 0) stakersSpcAddresses.remove(msg.sender);
        totalStakedAmount = totalStakedAmount.sub(amount);

        coinSpace.transfer(msg.sender, amount); //Lib.removeElement(stakers, msg.sender); // Ajouter rewards si nécessaire

        emit Withdrawn(msg.sender, amount);
    }

    // Internal function to create transaction from msg.sender to smart contract
    function transactionCoinSpace() internal {
        uint amountToTransfer = feesCreation.mul(10 ** 18);

        require(getBalanceCoinSpace(msg.sender) >= amountToTransfer, "Insufficient ERC-20 balance");
        coinSpace.burn(amountToTransfer, msg.sender);
    }

    /************************ GETTER FUNCTIONS *************************/

    function getBalanceCoinSpace(address user) public view returns (uint) {
        return coinSpace.balanceOf(user);
    }
    // Internal function to check if user has enough funds to pay NFT tax.

    /************************ CHANGER FUNCTIONS *************************/

    // Function to change the fees required for NFT operations.
    function changeFees(uint _fees) external onlyOwner {
        fees = _fees.mul(1 ether);
    }

    function changeRewardCreators(uint _reward) external onlyOwner {
        rewardPercentageCreator = _reward;
    }
    // Function to change the fees required for NFT creation.
    function changeFeesCreation(uint _feesCreation) external onlyOwner {
        feesCreation = _feesCreation;
    }

    //Function to change reward checkGps in SPC
    function changeRewardUser(uint _amountReward) external onlyOwner {
        amountRewardUser = _amountReward;
    }

    // Function to change the owner of the contract.
    function changeOwner(address _newOwner) external onlyOwner {
        contractOwner = _newOwner;
        transferOwnership(_newOwner);
    }

    function setAddressToken(address _tokenErc20) external onlyOwner {
        coinSpace = SpaceCoin(_tokenErc20);
    }

    function setAddressGame(address _game) external onlyOwner {
        game = GeoSpace(_game);
    }

    function setAddressAirdropToken(address _airdrop, address _token) external onlyOwner {
        airdrop = AirDrop(_airdrop);
        airdrop.setAddressToken(_token);
    }

    function setDistribution() external onlyOwner {
        airdrop.setDistributions();
    }

    /************************ REWARD FUNCTIONS *************************/

    function getRatioCreator(address player) public view returns (uint) {
        uint totalNft = game.getTotalNft();

        return game.getIdsCreator(player).length.mul(10 ** 18).div(totalNft);
    }

    function getRatioStaker(address player) public view returns (uint) {
        return stakedBalance[player].mul(10 ** 18).div(totalStakedAmount);
    }

    function rewardCreatorsGsp(uint tokenId) internal {
        uint totalCreators = creatorNftAddresses.length();

        if (totalCreators == 0) return;

        for (uint i = 0; i < totalCreators; i++) {
            address creator = creatorNftAddresses.at(i);

            if (creator != msg.sender && creator != contractOwner) {
                uint ratio = getRatioCreator(creator);
                uint feeShare = feesRewardCreator.mul(ratio).div(10 ** 18);

                balanceRewardCreator[creator] = balanceRewardCreator[creator].add(feeShare);
                ratioRewardCreator[creator] = ratio;
                emit RewardCreators(creator, feeShare, tokenId);
            }
        }
    }

    // Internal function to reward the user with ERC-20 tokens
    function rewardSpaceCoinPlayer(address user, uint amountReward, uint tokenId) internal {
        uint mintAmount = amountReward.mul(10 ** 18);

        coinSpace.mint(user, mintAmount);

        emit RewardWinner(user, mintAmount, tokenId);
    }

    function rewardStakersSpc(uint tokenId) internal {
        if (stakersSpcAddresses.length() <= 0) return;

        for (uint i = 0; i < stakersSpcAddresses.length(); i++) {
            address staker = stakersSpcAddresses.at(i);
            uint stakerBalance = stakedBalance[staker];

            if (stakerBalance > 0) {
                uint ratio = getRatioStaker(staker);
                uint feeShare = rewardFeesStakers.mul(ratio).div(10 ** 18);
                ratioRewardStaker[staker] = ratio;
                balanceRewardStaker[staker] = balanceRewardStaker[staker].add(feeShare);
                emit RewardStakers(staker, feeShare, tokenId);
            }
        }
    }

    function rewardTeams(uint tokenId) internal {
        uint amtReward = rewardFeesTeams;

        if (stakersSpcAddresses.length() == 0) {
            amtReward = rewardFeesTeams.add(rewardFeesTeams);
        }
        balanceTeams = balanceTeams.add(amtReward);
        emit RewardTeams(contractOwner, amtReward, balanceTeams, tokenId);
    }

    function rewardCreatorAndOwner(address actualOwner, uint tokenId) internal {
        if (winningFees[tokenId] == 0) return;
        uint feesWin = winningFees[tokenId];

        address creator = game.tokenCreationAddress(tokenId);

        uint amtCreator = feesWin.mul(rewardPercentageCreator).div(100);

        // Calculer le reste pour le propriétaire en utilisant SafeMath
        uint amtOwner = feesWin.sub(amtCreator);

        // (bool success, ) = previousOwner.call{ value: amtOwner }("");
        // (bool successCrea, ) = creator.call{ value: amtCreator }("");

        // require(success, "Refund failed");
        // require(successCrea, "Refund failed");
        balanceRewardOwner[creator] = balanceRewardOwner[creator].add(amtCreator);
        balanceRewardOwner[actualOwner] = balanceRewardOwner[actualOwner].add(amtOwner);

        emit RewardCreatorFees(creator, amtCreator, tokenId);
        emit RewardOwnerFees(actualOwner, amtOwner, tokenId);
    }

    function refundPlayer(address player, uint tokenId) internal {
        (bool success, ) = player.call{ value: winningFees[tokenId] }("");
        require(success, "Refund failed");
    }

    /************************ CLAIM GAME FUNCTIONS *************************/

    function claimRewardCreator() external nonReentrant {
        require(balanceRewardCreator[msg.sender] > 0, "your balance is Zero");
        uint cpyAmt = balanceRewardCreator[msg.sender];
        balanceRewardCreator[msg.sender] = 0;
        coinSpace.mint(msg.sender, cpyAmt);
    }

    function claimRewardCreatorOwnerFees() external nonReentrant {
        require(balanceRewardOwner[msg.sender] > 0, "your balance is Zero");
        uint cpyAmt = balanceRewardOwner[msg.sender];
        balanceRewardOwner[msg.sender] = 0;
        (bool success, ) = msg.sender.call{ value: cpyAmt }("");
        require(success, "Reward transfer failed");
    }

    function claimRewardTeams() external onlyOwner nonReentrant {
        require(balanceTeams > 0, "your balance is Zero");
        uint cpyAmt = balanceTeams;
        balanceTeams = 0;
        (bool success, ) = msg.sender.call{ value: cpyAmt }("");
        require(success, "Reward transfer failed");
    }

    /************************ AIRDROP FUNCTIONS *************************/

    function claimAirDrop() external nonReentrant {
        airdrop.claimTokens(
            msg.sender,
            game.getNftWinnerForUser(msg.sender).length,
            game.getIdsCreator(msg.sender).length
        );
    }

    function claimAirDropTeams() external onlyOwner nonReentrant {
        airdrop.claimTeamsTokens(msg.sender, counterGuess.current(), counterCreatorPlayers.current());
    }
    function estimateRewardPlayer() external {
        airdrop.estimateRewards(
            msg.sender,
            game.getNftWinnerForUser(msg.sender).length,
            game.getIdsCreator(msg.sender).length
        );
    }

    function estimateRewardTeams() external onlyOwner {
        airdrop.estimateRewardTeams(msg.sender, counterGuess.current(), counterCreatorPlayers.current());
    }

    function callAirDropStakers(uint amtMinimumStake) external onlyOwner {
        for (uint i = 0; i < stakersSpcAddresses.length(); i++) {
            uint amt = stakedBalance[stakersSpcAddresses.at(i)];
            if (amt > amtMinimumStake) {
                airdrop.airdropStaker(stakersSpcAddresses.at(i));
            }
        }
    }
}
