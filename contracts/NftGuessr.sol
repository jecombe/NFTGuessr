// @title NftGuessr - Smart contract for a location-based NFT guessing game.
// @author [Jérémy Combe]
// @notice This contract extends ERC721Enumerable for NFT functionality.
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./libraries/Lib.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NftGuessr is Ownable, ReentrancyGuard {
    /* LIBRARIES */
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    Counters.Counter public counterGuess;
    Counters.Counter public counterCreatorPlayers;

    EnumerableSet.AddressSet private creatorNftAddresses;
    EnumerableSet.AddressSet private stakersSpcAddresses;

    uint256 public totalStakedAmount;
    string private _baseTokenURI; // Don't use actually
    address public contractOwner;
    uint256 public fees = 2 ether; // Fees (Zama) base
    uint256 public feesCreation = 1; // Fees (SPC) nft creation Geospace
    uint256 public feesRewardCreator = 1;
    uint256 public amountRewardUser = 1; // amount reward winner
    uint256 public balanceTeams = 0;
    uint256 public rewardPercentageCreator = 3;

    SpaceCoin private coinSpace; // CoinSpace interface token Erc20
    GeoSpace private game;
    AirDrop private airdrop;

    mapping(address => uint256) public balanceRewardStaker;
    mapping(address => uint256) public balanceRewardCreator;
    mapping(address => uint256) public balanceRewardCreatorOwnerFees;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public lastStakeUpdateTime;

    /* EVENT */
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event GpsCheckResult(address indexed user, bool result, uint256 tokenId); // Event emitted when a user checks the GPS coordinates against an NFT location.
    event createNFT(address indexed user, uint256 tokenId, uint256 fee); // Event emitted when a new NFT is created.
    event ResetNFT(address indexed user, uint256 tokenId, bool isReset, uint256 tax); // Event emitted when an NFT is reset.
    event RewardWinner(address indexed user, uint256 amount); // Event to see when user receive reward token.
    event RewardCreators(address indexed user, uint256 amountReward, uint256 balance); // Event to see when user receive reward token.
    event RewardCreatorFees(address indexed user, uint256 amountReward, uint256 balance); // Event to see when user receive reward token.
    event RewardOwnerFees(address indexed user, uint256 amountReward, uint256 balance);
    event RewardStakers(address indexed user, uint256 amountReward, uint256 balance); // Event to see when user receive reward token.
    event RewardTeams(address indexed user, uint256 amountReward, uint256 balance); // Event to see when user receive reward token.

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

            require(game.getLifePoints(msg.sender) > 0, "your life points mint is over");
            if (!creatorNftAddresses.contains(msg.sender)) {
                creatorNftAddresses.add(msg.sender);
            }
            counterCreatorPlayers.increment();
            game.subLifePoint(msg.sender);
            uint256 tokenId = game.mint(msg.sender, data, feesData[i], baseIndex);
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
        uint256 _tokenId
    ) external payable nonReentrant {
        require(
            msg.value >= fees,
            string(abi.encodePacked("Insufficient fees. A minimum of ", fees, " ZAMA is required."))
        );

        // address actualOwner = ownerNft[_tokenId];
        address actualOwner = game.getActualOwner(_tokenId);

        uint256 missingFunds = checkFees(_tokenId, actualOwner);
        require(missingFunds == 0, string(abi.encodePacked("Insufficient funds. Missing ", missingFunds, " wei")));
        bool isWin = game.checkGps(msg.sender, userLatitude, userLongitude, _tokenId);
        counterGuess.increment();
        rewardStakersSpc();
        rewardTeams();
        rewardCreatorsGsp();
        if (isWin) {
            rewardUserWithERC20(msg.sender, amountRewardUser); //reward token SpaceCoin to user
            rewardCreatorAndOwner(actualOwner, _tokenId);
        } else {
            refundPlayer(msg.sender, actualOwner, _tokenId);
        }
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

    /************************ COINS FUNCTIONS *************************/

    function stakeSPC(uint256 amount) external {
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

    function unstakeSPC(uint256 amount) external {
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
        uint256 amountToTransfer = feesCreation.mul(10 ** 18);

        require(getBalanceCoinSpace(msg.sender) >= amountToTransfer, "Insufficient ERC-20 balance");
        coinSpace.burn(amountToTransfer, msg.sender);
    }

    /************************ GETTER FUNCTIONS *************************/

    function getBalanceCoinSpace(address user) public view returns (uint256) {
        return coinSpace.balanceOf(user);
    }

    function getBalanceRewardStaker(address user) external view returns (uint256) {
        return balanceRewardStaker[user];
    }

    function getBalanceRewardCreator(address user) external view returns (uint256) {
        return balanceRewardCreator[user];
    }

    function getBalanceRewardCreatorOwnerFees(address user) external view returns (uint256) {
        return balanceRewardCreatorOwnerFees[user];
    }

    function getBalanceStake(address _player) public view returns (uint256) {
        return stakedBalance[_player];
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

    /************************ CHANGER FUNCTIONS *************************/

    // Function to change the fees required for NFT operations.
    function changeFees(uint256 _fees) external onlyOwner {
        fees = _fees.mul(1 ether);
    }

    function changeRewardCreators(uint _reward) external onlyOwner {
        rewardPercentageCreator = _reward;
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

    function rewardCreatorsGsp() internal {
        uint256 totalCreators = creatorNftAddresses.length();
        if (totalCreators == 0) return;
        uint256 totalNft = game.getTotalNft();
        for (uint256 i = 0; i < totalCreators; i++) {
            address creator = creatorNftAddresses.at(i);

            if (creator != msg.sender && creator != contractOwner) {
                uint256 ratio = game.getIdsCreator(creator).length.mul(10 ** 18).div(totalNft);
                uint256 feeShare = feesRewardCreator.mul(ratio).div(10 ** 18);
                balanceRewardCreator[creator] = balanceRewardCreator[creator].add(feeShare);
                emit RewardCreators(creator, feeShare, balanceRewardCreator[creator]);
            }
        }
    }

    // Internal function to reward the user with ERC-20 tokens
    function rewardUserWithERC20(address user, uint256 amountReward) internal {
        uint256 mintAmount = amountReward.mul(10 ** 18);

        coinSpace.mint(user, mintAmount);

        emit RewardWinner(user, mintAmount);
    }

    function rewardStakersSpc() internal {
        if (stakersSpcAddresses.length() <= 0) return;

        uint256 rewardForStaker = 1 ether;

        for (uint256 i = 0; i < stakersSpcAddresses.length(); i++) {
            address staker = stakersSpcAddresses.at(i);
            uint256 stakerBalance = stakedBalance[staker];

            if (stakerBalance > 0) {
                uint256 stakerRatio = stakerBalance.mul(10 ** 18).div(totalStakedAmount);
                uint256 stakerReward = rewardForStaker.mul(stakerRatio).div(10 ** 18);
                balanceRewardStaker[staker] = balanceRewardStaker[staker].add(stakerReward);
                emit RewardStakers(staker, stakerReward, balanceRewardStaker[staker]);
            }
        }
    }

    function rewardTeams() internal {
        uint256 rewardForOwner = 1 ether;
        if (stakersSpcAddresses.length() < 1) {
            rewardForOwner = rewardForOwner.add(1 ether);
        }
        balanceTeams = balanceTeams.add(rewardForOwner);
        emit RewardTeams(contractOwner, rewardForOwner, balanceTeams);
    }

    function rewardCreatorAndOwner(address actualOwner, uint256 _tokenId) internal {
        address creator = game.getAddressCreationWithToken(_tokenId);
        uint256 totalAmt = game.getFee(actualOwner, _tokenId);
        if (totalAmt == 0) return;

        // Calculer 3% de totalAmt en utilisant SafeMath
        uint256 amtCreator = totalAmt.mul(rewardPercentageCreator).div(100);

        // Calculer le reste pour le propriétaire en utilisant SafeMath
        uint256 amtOwner = totalAmt.sub(amtCreator);

        balanceRewardCreatorOwnerFees[creator] = balanceRewardCreatorOwnerFees[creator].add(amtCreator);
        balanceRewardCreatorOwnerFees[actualOwner] = balanceRewardCreatorOwnerFees[actualOwner].add(amtOwner);
        emit RewardCreatorFees(creator, amtCreator, balanceRewardCreatorOwnerFees[creator]);
        emit RewardOwnerFees(actualOwner, amtOwner, balanceRewardCreatorOwnerFees[actualOwner]);
    }

    function refundPlayer(address player, address owner, uint tokenId) internal {
        uint256 nftFees = game.getFee(owner, tokenId);

        (bool success, ) = player.call{ value: nftFees }("");
        require(success, "Refund failed");
    }

    /************************ CLAIM GAME FUNCTIONS *************************/

    function claimRewardStaker() external nonReentrant {
        require(balanceRewardStaker[msg.sender] > 0, "Your balance is zero");

        uint cpyAmt = balanceRewardStaker[msg.sender];
        balanceRewardStaker[msg.sender] = 0;
        (bool success, ) = msg.sender.call{ value: cpyAmt }("");
        require(success, "Reward transfer failed");
    }

    function claimRewardCreator() external nonReentrant {
        require(balanceRewardCreator[msg.sender] > 0, "your balance is Zero");
        uint cpyAmt = balanceRewardCreator[msg.sender];
        balanceRewardCreator[msg.sender] = 0;
        coinSpace.mint(msg.sender, cpyAmt);
    }

    function claimRewardCreatorOwnerFees() external nonReentrant {
        require(balanceRewardCreatorOwnerFees[msg.sender] > 0, "your balance is Zero");
        uint cpyAmt = balanceRewardCreatorOwnerFees[msg.sender];
        balanceRewardCreatorOwnerFees[msg.sender] = 0;
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
