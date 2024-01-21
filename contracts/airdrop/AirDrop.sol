// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../structs/StructsNftGuessr.sol";
import "../erc20/SpaceCoin.sol";

contract AirDrop is Ownable {
    using SafeMath for uint256;

    SpaceCoin private coinSpace; // CoinSpace interface token Erc20
    uint256[3] private distributionPercentages = [80, 10, 10]; // 80% for one purpose, 20% for another
    mapping(address => uint256) public playerBalances;
    mapping(address => uint256) private lengthWon;
    mapping(address => uint256) private lengthCrea;
    uint256 balanceForAirDrop;
    uint256 balanceForTeams;
    uint256 balanceForBounty;
    bool public isOver;

    uint256 balanceAirDropCpy;
    uint256 balanceAirDropTeamsCpy;

    uint256 public constant WEEKLY_AIRDROP_AMOUNT = 3;
    uint256 public lastAirdropTimestamp;

    event ClaimAirDrop(address indexed user, uint amount, uint balanceAirDrop);

    constructor(address _nftGuessr) {
        transferOwnership(_nftGuessr);
    }

    function setAddressToken(address _tokenErc20) external onlyOwner {
        coinSpace = SpaceCoin(_tokenErc20);
    }

    function setDistributions() public onlyOwner {
        uint256 totalBalance = coinSpace.balanceOf(address(this));

        uint256 distribution1 = totalBalance.mul(distributionPercentages[0]).div(100);
        uint256 distribution2 = totalBalance.mul(distributionPercentages[1]).div(100);
        uint256 distribution3 = totalBalance.mul(distributionPercentages[2]).div(100);

        balanceForAirDrop = distribution1;
        balanceAirDropCpy = distribution1;
        balanceForBounty = distribution2;
        balanceForTeams = distribution3;
        balanceAirDropTeamsCpy = distribution3;
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
        require(!isOver, "the airdrop players is finish");
        airdropGuess(player, countWon);
        airdropCreator(player, countCrea);

        uint amount = playerBalances[player];

        require(amount > 0, "No tokens to claim");

        uint256 transferAmt = amount.mul(10 ** 18);
        balanceForAirDrop = balanceForAirDrop.sub(amount);
        playerBalances[player] = 0;
        coinSpace.transfer(player, transferAmt);

        emit ClaimAirDrop(player, amount, balanceForAirDrop);
    }

    function estimateRewards(address player, uint256 countWon, uint256 countCrea) public onlyOwner {
        require(address(coinSpace) != address(0), "Token address not set");
        require(!isOver, "the airdrop players is finish");
        airdropGuess(player, countWon);
        airdropCreator(player, countCrea);
    }

    // Airdrop tokens based on GspWon * 2 + 10 and use the 80% distribution
    function airdropGuess(address _player, uint256 _nbGuessWon) internal returns (bool) {
        if (_nbGuessWon < 1) return false;
        uint256 diff = _nbGuessWon.sub(lengthWon[_player]);

        if (diff <= 0) return false;

        lengthWon[_player] = _nbGuessWon;

        uint256 amountToAirdrop = diff.mul(2).add(6);
        uint256 checkBalance = balanceAirDropCpy.sub(amountToAirdrop);

        if (balanceAirDropCpy > 0 && checkBalance > 0) {
            playerBalances[_player] = playerBalances[_player].add(amountToAirdrop);
            balanceAirDropCpy = balanceAirDropCpy.sub(amountToAirdrop);
            return true;
        } else if (checkBalance == 0 && balanceAirDropCpy > 0) {
            playerBalances[_player] = balanceAirDropCpy;
            balanceAirDropTeamsCpy = 0;
            isOver = true;
        }
        return false;
    }

    function airdropCreator(address _player, uint256 _nbCreation) internal returns (bool) {
        if (_nbCreation < 1) return false;

        uint256 diff = _nbCreation.sub(lengthCrea[_player]);

        if (diff <= 0) return false;

        lengthCrea[_player] = _nbCreation;
        uint256 amountToAirdrop = diff.mul(2).add(4);

        uint256 checkBalance = balanceAirDropCpy.sub(amountToAirdrop);
        if (balanceAirDropCpy > 0 && checkBalance > 0) {
            playerBalances[_player] = playerBalances[_player].add(amountToAirdrop);
            balanceAirDropCpy = balanceAirDropCpy.sub(amountToAirdrop);
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

        uint256 checkBalance = balanceAirDropCpy.sub(WEEKLY_AIRDROP_AMOUNT);

        if (balanceForAirDrop > 0 && checkBalance > 0) {
            playerBalances[_player] = playerBalances[_player].add(WEEKLY_AIRDROP_AMOUNT);
            balanceAirDropCpy = balanceAirDropCpy.sub(WEEKLY_AIRDROP_AMOUNT);
        } else revert("No balance");
    }

    function claimTeamsTokens(address player, uint256 countWon, uint256 countCrea) public onlyOwner {
        airdropTeamsGuess(player, countWon);
        airdropTeamsCreator(player, countCrea);
        require(playerBalances[player] > 0, "No tokens to claim");

        uint256 transferAmt = playerBalances[player].mul(10 ** 18);
        balanceForTeams = balanceForTeams.sub(playerBalances[player]);
        playerBalances[player] = 0;
        coinSpace.transfer(player, transferAmt);
    }

    function estimateRewardTeams(address _teams, uint256 _counterGuess, uint256 _counterMint) public onlyOwner {
        airdropTeamsGuess(_teams, _counterGuess);
        airdropTeamsCreator(_teams, _counterMint);
    }

    function airdropTeamsGuess(address teams, uint256 _counterGuess) internal returns (bool) {
        if (_counterGuess < 1) return false;
        uint256 diff = _counterGuess.sub(lengthWon[teams]);

        if (diff <= 0) return false;

        lengthWon[teams] = _counterGuess;

        uint256 amountToAirdrop = diff.mul(2).add(4);
        uint256 checkBalance = balanceAirDropTeamsCpy.sub(amountToAirdrop);

        if (balanceAirDropTeamsCpy > 0 && checkBalance > 0) {
            playerBalances[teams] = playerBalances[teams].add(amountToAirdrop);
            balanceAirDropTeamsCpy = balanceAirDropTeamsCpy.sub(amountToAirdrop);
            return true;
        } else if (checkBalance == 0 && balanceAirDropTeamsCpy > 0) {
            playerBalances[teams] = balanceAirDropTeamsCpy;
            balanceAirDropTeamsCpy = 0;
        }
        return false;
    }

    function airdropTeamsCreator(address teams, uint256 _counterMint) internal returns (bool) {
        if (_counterMint < 1) return false;

        uint256 diff = _counterMint.sub(lengthCrea[teams]);

        if (diff <= 0) return false;

        lengthCrea[teams] = _counterMint;
        uint256 amountToAirdrop = diff.mul(2).add(2);

        uint256 checkBalance = balanceAirDropTeamsCpy.sub(amountToAirdrop);
        if (balanceAirDropTeamsCpy > 0 && checkBalance > 0) {
            playerBalances[teams] = playerBalances[teams].add(amountToAirdrop);
            balanceAirDropTeamsCpy = balanceAirDropTeamsCpy.sub(amountToAirdrop);
            return true;
        } else if (checkBalance == 0 && balanceAirDropTeamsCpy > 0) {
            playerBalances[teams] = balanceAirDropTeamsCpy;
            balanceAirDropTeamsCpy = 0;
        }
        return false;
    }

    function airdropTeams(uint256 _counterGuess, uint256 _counterMint) public onlyOwner {
        require(address(coinSpace) != address(0), "Token address not set");

        uint256 amountToAirdropGuess = _counterGuess.mul(distributionPercentages[1]).div(10000); // 0.01%
        uint256 amountToAirdropMint = _counterMint.mul(2).div(10000); // 0.02%
        uint256 totalAmountToAirdrop = amountToAirdropGuess.add(amountToAirdropMint);

        if (balanceForTeams > 0) {
            playerBalances[msg.sender] = playerBalances[msg.sender].add(totalAmountToAirdrop);
            lastAirdropTimestamp = block.timestamp;
            balanceForTeams = balanceForTeams.sub(totalAmountToAirdrop);
        }
    }
}
