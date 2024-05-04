// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../structs/StructsNftGuessr.sol";
import "../erc20/SpaceCoin.sol";

contract AirDrop is Ownable {
    SpaceCoin private coinSpace; // CoinSpace interface token Erc20
    uint[3] private distributionPercentages = [80, 10, 10]; // 80% for one purpose, 20% for another
    mapping(address => uint) public playerBalances;
    mapping(address => uint) private lengthWon;
    mapping(address => uint) private lengthCrea;
    uint balanceForAirDrop;
    uint balanceForTeams;
    uint balanceForBounty;
    bool public isOver;

    uint balanceAirDropCpy;
    uint balanceAirDropTeamsCpy;

    uint public constant WEEKLY_AIRDROP_AMOUNT = 3;
    uint public lastAirdropTimestamp;

    event ClaimAirDrop(address indexed user, uint amount, uint balanceAirDrop);

    constructor(address _nftGuessr) Ownable(_nftGuessr) {
        transferOwnership(_nftGuessr);
    }

    function setAddressToken(address _tokenErc20) external onlyOwner {
        coinSpace = SpaceCoin(_tokenErc20);
    }

    function setDistributions() public onlyOwner {
        uint totalBalance = coinSpace.balanceOf(address(this));

        uint distribution1 = (totalBalance * distributionPercentages[0]) / 100;
        uint distribution2 = (totalBalance * distributionPercentages[1]) / 100;
        uint distribution3 = (totalBalance * distributionPercentages[2]) / 100;

        balanceForAirDrop = distribution1;
        balanceAirDropCpy = distribution1;
        balanceForBounty = distribution2;
        balanceForTeams = distribution3;
        balanceAirDropTeamsCpy = distribution3;
    }

    function getBalanceAirDrop() public view returns (uint) {
        return balanceForAirDrop;
    }

    function getBalanceBounty() public view returns (uint) {
        return balanceForBounty;
    }

    function getBalanceTeams() public view returns (uint) {
        return balanceForTeams;
    }

    function getBalanceAirdrop(address _user) public view returns (uint) {
        return playerBalances[_user];
    }

    // Function for players to claim their tokens
    function claimTokens(address player, uint countWon, uint countCrea) public onlyOwner {
        require(!isOver, "the airdrop players is finish");
        airdropGuess(player, countWon);
        airdropCreator(player, countCrea);

        uint amount = playerBalances[player];

        require(amount > 0, "No tokens to claim");

        uint transferAmt = amount * 10 ** 18;
        balanceForAirDrop -= amount;
        playerBalances[player] = 0;
        coinSpace.transfer(player, transferAmt);

        emit ClaimAirDrop(player, amount, balanceForAirDrop);
    }

    function estimateRewards(address player, uint countWon, uint countCrea) public onlyOwner {
        require(address(coinSpace) != address(0), "Token address not set");
        require(!isOver, "the airdrop players is finish");
        airdropGuess(player, countWon);
        airdropCreator(player, countCrea);
    }

    // Airdrop tokens based on GspWon * 2 + 10 and use the 80% distribution
    function airdropGuess(address _player, uint _nbGuessWon) internal returns (bool) {
        if (_nbGuessWon < 1) return false;
        uint diff = _nbGuessWon - lengthWon[_player];

        if (diff <= 0) return false;

        lengthWon[_player] = _nbGuessWon;

        uint amountToAirdrop = diff * 2 + 6;
        uint checkBalance = balanceAirDropCpy - amountToAirdrop;

        if (balanceAirDropCpy > 0 && checkBalance > 0) {
            playerBalances[_player] += amountToAirdrop;
            balanceAirDropCpy -= amountToAirdrop;
            return true;
        } else if (checkBalance == 0 && balanceAirDropCpy > 0) {
            playerBalances[_player] = balanceAirDropCpy;
            balanceAirDropTeamsCpy = 0;
            isOver = true;
        }
        return false;
    }

    function airdropCreator(address _player, uint _nbCreation) internal returns (bool) {
        if (_nbCreation < 1) return false;

        uint diff = _nbCreation - lengthCrea[_player];

        if (diff <= 0) return false;

        lengthCrea[_player] = _nbCreation;
        uint amountToAirdrop = diff * 2 + 4;

        uint checkBalance = balanceAirDropCpy - amountToAirdrop;
        if (balanceAirDropCpy > 0 && checkBalance > 0) {
            playerBalances[_player] += amountToAirdrop;
            balanceAirDropCpy -= amountToAirdrop;
            return true;
        } else if (checkBalance == 0 && balanceAirDropCpy > 0) {
            playerBalances[_player] = balanceAirDropCpy;
            balanceAirDropTeamsCpy = 0;
            isOver = true;
        }
        return false;
    }

    // Airdrop function for stakers (called once per week)
    function airdropStaker(address _player) public onlyOwner {
        require(address(coinSpace) != address(0), "Token address not set");

        uint checkBalance = balanceAirDropCpy - WEEKLY_AIRDROP_AMOUNT;

        if (balanceForAirDrop > 0 && checkBalance > 0) {
            playerBalances[_player] += WEEKLY_AIRDROP_AMOUNT;
            balanceAirDropCpy -= WEEKLY_AIRDROP_AMOUNT;
        } else revert("No balance");
    }

    function claimTeamsTokens(address player, uint countWon, uint countCrea) public onlyOwner {
        airdropTeamsGuess(player, countWon);
        airdropTeamsCreator(player, countCrea);
        require(playerBalances[player] > 0, "No tokens to claim");

        uint transferAmt = playerBalances[player] * 10 ** 18;
        balanceForTeams -= playerBalances[player];
        playerBalances[player] = 0;
        coinSpace.transfer(player, transferAmt);
    }

    function estimateRewardTeams(address _teams, uint _counterGuess, uint _counterMint) public onlyOwner {
        airdropTeamsGuess(_teams, _counterGuess);
        airdropTeamsCreator(_teams, _counterMint);
    }

    function airdropTeamsGuess(address teams, uint _counterGuess) internal returns (bool) {
        if (_counterGuess < 1) return false;
        uint diff = _counterGuess - lengthWon[teams];

        if (diff <= 0) return false;

        lengthWon[teams] = _counterGuess;

        uint amountToAirdrop = diff * 2 + 4;
        uint checkBalance = balanceAirDropTeamsCpy - amountToAirdrop;

        if (balanceAirDropTeamsCpy > 0 && checkBalance > 0) {
            playerBalances[teams] += amountToAirdrop;
            balanceAirDropTeamsCpy -= amountToAirdrop;
            return true;
        } else if (checkBalance == 0 && balanceAirDropTeamsCpy > 0) {
            playerBalances[teams] = balanceAirDropTeamsCpy;
            balanceAirDropTeamsCpy = 0;
        }
        return false;
    }

    function airdropTeamsCreator(address teams, uint _counterMint) internal returns (bool) {
        if (_counterMint < 1) return false;

        uint diff = _counterMint - lengthCrea[teams];

        if (diff <= 0) return false;

        lengthCrea[teams] = _counterMint;
        uint amountToAirdrop = diff * 2 + 2;

        uint checkBalance = balanceAirDropTeamsCpy - amountToAirdrop;
        if (balanceAirDropTeamsCpy > 0 && checkBalance > 0) {
            playerBalances[teams] += amountToAirdrop;
            balanceAirDropTeamsCpy -= amountToAirdrop;
            return true;
        } else if (checkBalance == 0 && balanceAirDropTeamsCpy > 0) {
            playerBalances[teams] = balanceAirDropTeamsCpy;
            balanceAirDropTeamsCpy = 0;
        }
        return false;
    }

    function airdropTeams(uint _counterGuess, uint _counterMint) public onlyOwner {
        require(address(coinSpace) != address(0), "Token address not set");

        uint amountToAirdropGuess = (_counterGuess * distributionPercentages[1]) / 10000; // 0.01%
        uint amountToAirdropMint = (_counterMint * 2) / 10000; // 0.02%
        uint totalAmountToAirdrop = amountToAirdropGuess + amountToAirdropMint;

        if (balanceForTeams > 0) {
            playerBalances[msg.sender] += totalAmountToAirdrop;
            lastAirdropTimestamp = block.timestamp;
            balanceForTeams -= totalAmountToAirdrop;
        }
    }
}
