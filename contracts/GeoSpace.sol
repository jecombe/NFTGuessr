pragma solidity ^0.8.19;
import "fhevm/lib/TFHE.sol";
import "./library/GeoSpaceUtility.sol";
import "./interfaces/INFT.sol";

contract GeoSpace is INFT {
    string public name = "GeoSpace";
    string public symbol = "GSP";
    uint256 public nextTokenId = 1;
    uint256 public stakedNFTCount = 0;
    uint256 public resetNFTCount = 0;
    uint public nbNftStake = 3;

    uint256 public fees;
    address public owner;
    NFT[] public nfts;

    mapping(address => bool) public hasStakedEnoughNFTs;
    mapping(address => uint256[]) public nftsByOwner;
    mapping(address => uint256[]) public stakedNFTsByOwner;
    mapping(address => uint256[]) public resetNFTsByOwner;

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can perform this action");
        _;
    }

    function addNFTToOwner(address _owner, uint256 tokenId) internal {
        nftsByOwner[_owner].push(tokenId);
    }

    function getNFTsLength() external view returns (uint256) {
        return nfts.length;
    }

    function getNFTsByOwner(address _owner) public view returns (uint256[] memory) {
        return nftsByOwner[_owner];
    }

    function getNFTsStakedByOwner(address _owner) public view returns (uint256[] memory) {
        return stakedNFTsByOwner[_owner];
    }

    function getNFTsResetByOwner(address _owner) public view returns (uint256[] memory) {
        return resetNFTsByOwner[_owner];
    }

    function getTotalNFTs() public view returns (uint256) {
        return nfts.length;
    }

    function getTotalStakedNFTs() public view returns (uint256) {
        return stakedNFTCount;
    }

    function getTotalResetNFTs() public view returns (uint256) {
        return resetNFTCount;
    }

    function getHasStakedEnoughNFTs(address user) public view returns (bool) {
        return hasStakedEnoughNFTs[user];
    }

    function changeFees(uint256 _fees) public onlyOwner {
        fees = _fees * 1 ether;
    }

    function changeNbNftStake(uint256 _nb) public onlyOwner {
        nbNftStake = _nb;
    }

    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    function changeNFTTax(uint256 tokenId, uint256 newTax) public view {
        GeoSpaceUtility.changeNFTTax(nfts, tokenId, newTax);
    }

    function setTax(uint256 tokenId, uint256 newTax) public view {
        GeoSpaceUtility.setTax(nfts, tokenId, newTax);
    }

    function getNFTLocation(uint256 tokenId) public view onlyOwner returns (INFT.NFTLocation memory) {
        return GeoSpaceUtility.getNFTLocation(nfts, tokenId, nextTokenId);
    }

    function getNFTLocationOwner(uint256 tokenId) public view returns (INFT.NFTLocation memory) {
        return GeoSpaceUtility.getNFTLocationOwner(nfts, tokenId, nextTokenId);
    }
}
