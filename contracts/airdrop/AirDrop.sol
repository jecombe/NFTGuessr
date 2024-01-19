// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../libraries/LibrariesNftGuessr.sol";
import "../structs/StructsNftGuessr.sol";
import "../erc20/Erc20.sol";

contract AirDrop is Ownable {
    using SafeMath for uint256;

    CoinSpace private coinSpace; // CoinSpace interface token Erc20
    uint256[3] private distributionPercentages = [80, 10, 10]; // 80% for one purpose, 20% for another
    mapping(address => uint256) public playerBalances;
    mapping(address => uint256) private lengthWon;
    mapping(address => uint256) private lengthCrea;
    uint256 balanceForAirDrop;
    uint256 balanceForTeams;
    uint256 balanceForBounty;

    uint256 balanceAirDropCpy;

    uint256 public constant WEEKLY_AIRDROP_AMOUNT = 3;
    uint256 public lastAirdropTimestamp;

    event WithdrawAirdrop(address indexed user, uint256 amount);

    event EstimateAirdropGuess(address indexed user, uint256 amount);
    event EstimateAirdropCreator(address indexed user, uint256 amount);

    constructor(address _nftGuessr) {
        transferOwnership(_nftGuessr);
    }

    //receive() external payable {}

    // Change tokenAddress Erc20
    function setAddressToken(address _tokenErc20) external onlyOwner {
        coinSpace = CoinSpace(_tokenErc20);
    }

    function setDistributions() public onlyOwner {
        // Obtenez la balance totale du contrat
        uint256 totalBalance = coinSpace.balanceOf(address(this));

        // Calculez les montants pour chaque distribution
        uint256 distribution1 = totalBalance.mul(distributionPercentages[0]).div(100);
        uint256 distribution2 = totalBalance.mul(distributionPercentages[1]).div(100);
        uint256 distribution3 = totalBalance.mul(distributionPercentages[2]).div(100);

        // Utilisez les variables calculées comme nécessaire
        // Par exemple, vous pourriez les stocker dans des variables d'état ou les utiliser directement dans d'autres fonctions.

        // Exemple de stockage dans des variables d'état
        balanceForAirDrop = distribution1;
        balanceAirDropCpy = distribution1;
        balanceForBounty = distribution2;
        balanceForTeams = distribution3;
    }

    function getBalanceAirDrop() public view returns (uint256) {
        return balanceForAirDrop;
    }

    function getBalanceBounty() public view returns (uint256) {
        return balanceForBounty;
    }

    function getBalanceTeams() public view returns (uint256) {
        return balanceForTeams;
    }

    function getBalanceAirdrop(address _user) public view returns (uint256) {
        return playerBalances[_user];
    }

    // Function for players to claim their tokens
    function claimTokens(address player, uint256 countWon, uint256 countCrea) public onlyOwner {
        airdropGuess(player, countWon);
        airdropCreator(player, countCrea);
        require(playerBalances[player] > 0, "No tokens to claim");

        uint256 transferAmt = playerBalances[player].mul(10 ** 18);
        // Transfer the tokens from the contract to the player
        coinSpace.transfer(player, transferAmt);
        balanceForAirDrop = balanceForAirDrop.sub(playerBalances[player]);
        // Reset the player's balance to zero after claiming
        playerBalances[player] = 0;
    }

    function estimateRewards(address player, uint256 countWon, uint256 countCrea) public onlyOwner {
        require(address(coinSpace) != address(0), "Token address not set");
        // require(countWon > 0, "no Zero");

        airdropGuess(player, countWon);
        airdropCreator(player, countCrea);
    }

    // Airdrop tokens based on GspWon * 2 + 10 and use the 80% distribution
    function airdropGuess(address _player, uint256 _nbGuessWon) internal returns (uint256) {
        if (_nbGuessWon < 1) return 0;
        uint256 diff = _nbGuessWon.sub(lengthWon[_player]);

        if (diff <= 0) return 0;

        lengthWon[_player] = _nbGuessWon;

        uint256 amountToAirdrop = diff.mul(2).add(4);
        uint256 checkBalance = balanceAirDropCpy.sub(amountToAirdrop);

        if (balanceAirDropCpy > 0 && checkBalance > 0) {
            playerBalances[_player] = playerBalances[_player].add(amountToAirdrop);
            balanceAirDropCpy = balanceAirDropCpy.sub(amountToAirdrop);
            return amountToAirdrop;
        } else revert("No balance");
    }

    function airdropCreator(address _player, uint256 _nbCreation) internal returns (uint256) {
        if (_nbCreation < 1) return 0;

        uint256 diff = _nbCreation.sub(lengthCrea[_player]);

        if (diff <= 0) return 0;

        lengthCrea[_player] = _nbCreation;
        uint256 amountToAirdrop = diff.mul(2).add(6);

        uint256 checkBalance = balanceAirDropCpy.sub(amountToAirdrop);
        if (balanceAirDropCpy > 0 && checkBalance > 0) {
            playerBalances[_player] = playerBalances[_player].add(amountToAirdrop);
            balanceAirDropCpy = balanceAirDropCpy.sub(amountToAirdrop);
            return amountToAirdrop;
        } else revert("No balance");
    }

    // Airdrop function for stakers (called once per week)
    function airdropStaker(address _player) public onlyOwner {
        require(address(coinSpace) != address(0), "Token address not set");
        require(block.timestamp.sub(lastAirdropTimestamp) >= 1 weeks, "Airdrop can only be done once per week");

        // Credit 3 tokens to the player's balance
        uint256 amountToAirdrop = WEEKLY_AIRDROP_AMOUNT;

        // Check if the contract has sufficient balance
        if (balanceForAirDrop > 0) {
            playerBalances[_player] = playerBalances[_player].add(amountToAirdrop);

            // Update the last airdrop timestamp
            lastAirdropTimestamp = block.timestamp;
            balanceForAirDrop = balanceForAirDrop.sub(amountToAirdrop);
        }
    }

    function airdropTeams(uint256 _counterGuess) public onlyOwner {
        require(address(coinSpace) != address(0), "Token address not set");

        // Calculate the amount to be airdropped based on the formula
        uint256 amountToAirdrop = _counterGuess.mul(distributionPercentages[1]).div(10000);

        // Check if the contract has sufficient balance
        if (balanceForTeams > 0) {
            // Transfer the reserved amount to the specified address
            playerBalances[msg.sender] = playerBalances[msg.sender].add(amountToAirdrop);

            // Update the last airdrop timestamp
            lastAirdropTimestamp = block.timestamp;
            balanceForTeams = balanceForTeams.sub(amountToAirdrop);
        }
    }
}
