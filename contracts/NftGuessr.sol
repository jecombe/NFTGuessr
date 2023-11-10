// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "fhevm/lib/TFHE.sol";

contract NftGuessr {
    string public name = "GeoSpace"; // Ajout du nom de la collection
    string public symbol = "GSP"; // Ajout du symbole de la collection
    uint256 public nextTokenId = 1; // Compteur d'identifiants uniques
    // Compteur du nombre de NFTs "stakés"
    uint256 public stakedNFTCount = 0;
    uint256 public resetNFTCount = 0;

    uint public nbNftStake = 3;
    //  uint percentageFees = 5;

    struct Location {
        euint32 northLat;
        euint32 southLat;
        euint32 eastLon;
        euint32 westLon;
    }

    struct NFT {
        address owner;
        Location location;
        bool claimed;
        uint256 tokenId; // Ajout de l'identifiant unique
        bool isStaked;
        bool isReset;
        uint256 tax; // Nouvelle variable pour la taxe
        // uint256 fees; // Nouveau champ pour les frais du NFT
    }

    uint256 public fees;
    address public owner;
    NFT[] public nfts;
    // Indique si l'utilisateur a "staké" 3 NFTs
    mapping(address => bool) public hasStakedEnoughNFTs;
    mapping(address => uint256[]) public nftsByOwner;
    mapping(address => uint256[]) public stakedNFTsByOwner;
    mapping(address => uint256[]) public resetNFTsByOwner;

    constructor() {
        owner = msg.sender;
        fees = 1 ether;
    }

    // EVENT
    event GpsCheckResult(address indexed user, bool result, uint256 tokenId);
    event NFTTransfer(address indexed from, address indexed to, uint256 tokenId);
    event NFTReset(uint256 tokenId, address indexed owner, bool isReset, uint256 tax);
    event NFTTransferred(uint256 tokenId, address indexed from, address indexed to);
    event isAccess(bool isStake, address indexed from);
    event NftCount(address indexed owner, uint256 nftCount, uint256 nftId, bool isStake);
    event NftClaimed(uint256 tokenId, address indexed from);
    // MODIFER
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can perform this action");
        _;
    }

    // RECEIVER
    receive() external payable {
        // Cette fonction permet de recevoir des ethers
    }

    // function setPercentageFees(uint _percentageFees) public onlyOwner {
    //     percentageFees = _percentageFees;
    // }

    // function setNFTFees(uint256 nftIndex, uint256 newFees) public {
    //     require(nftIndex < nfts.length, "Invalid NFT index");
    //     require(msg.sender == nfts[nftIndex].owner, "You can only set fees for your own NFT");
    //     require(newFees <= fees * 5, "NFT fees cannot exceed 500% of the base fees");

    //     nfts[nftIndex].fees = newFees;
    // }

    // Ajouter un NFT à un propriétaire
    function addNFTToOwner(address _owner, uint256 tokenId) internal {
        nftsByOwner[_owner].push(tokenId);
    }

    // Supprimer un NFT de la liste du propriétaire
    function removeNFTFromOwner(address _owner, uint256 _tokenId) internal {
        uint256[] storage ownerNFTs = nftsByOwner[_owner];
        for (uint256 i = 0; i < ownerNFTs.length; i++) {
            if (ownerNFTs[i] == _tokenId) {
                if (i != ownerNFTs.length - 1) {
                    ownerNFTs[i] = ownerNFTs[ownerNFTs.length - 1];
                }
                ownerNFTs.pop();
                break;
            }
        }
    }

    function removeNftStakeFromOwner(address _owner, uint256 _tokenId) internal {
        uint256[] storage ownerNFTs = stakedNFTsByOwner[_owner];
        for (uint256 i = 0; i < ownerNFTs.length; i++) {
            if (ownerNFTs[i] == _tokenId) {
                if (i != ownerNFTs.length - 1) {
                    ownerNFTs[i] = ownerNFTs[ownerNFTs.length - 1];
                }
                ownerNFTs.pop();
                break;
            }
        }
    }

    function removeNftResetFromOwner(address _owner, uint256 _tokenId) internal {
        uint256[] storage ownerNFTs = resetNFTsByOwner[_owner];
        for (uint256 i = 0; i < ownerNFTs.length; i++) {
            if (ownerNFTs[i] == _tokenId) {
                if (i != ownerNFTs.length - 1) {
                    ownerNFTs[i] = ownerNFTs[ownerNFTs.length - 1];
                }
                ownerNFTs.pop();
                break;
            }
        }
    }

    //GETTER
    function getNFTOwnersAndTokenIds() public view returns (address[] memory, uint256[] memory) {
        address[] memory owners = new address[](nfts.length);
        uint256[] memory tokenIds = new uint256[](nfts.length);

        for (uint256 i = 0; i < nfts.length; i++) {
            owners[i] = nfts[i].owner;
            tokenIds[i] = nfts[i].tokenId;
        }

        return (owners, tokenIds);
    }

    // Fonction pour obtenir tous les NFTs associés à une adresse
    function getNFTsByOwner(address _owner) public view returns (uint256[] memory) {
        return nftsByOwner[_owner];
    }

    function getNFTsStakedByOwner(address _owner) public view returns (uint256[] memory) {
        return stakedNFTsByOwner[_owner];
    }

    function getNFTsResetByOwner(address _owner) public view returns (uint256[] memory) {
        return resetNFTsByOwner[_owner];
    }

    // Fonction interne pour ajouter un NFT à un propriétaire

    function getTotalNFTs() public view returns (uint256) {
        return nfts.length + 1;
    }

    function getTotalStakedNFTs() public view returns (uint256) {
        return stakedNFTCount;
    }

    function getTotalResetNFTs() public view returns (uint256) {
        return resetNFTCount;
    }

    // Fonction pour obtenir le nom de la collection
    function getName() public view returns (string memory) {
        return name;
    }

    function getNextTokenId() public view returns (uint256) {
        return nextTokenId;
    }

    // Fonction pour obtenir le symbole de la collection
    function getSymbol() public view returns (string memory) {
        return symbol;
    }

    function getHasStakedEnoughNFTs(address user) public view returns (bool) {
        return hasStakedEnoughNFTs[user];
    }

    //CHANGER
    function changeFees(uint256 _fees) public onlyOwner {
        fees = _fees * 1 ether;
    }

    function changeNbNftStake(uint256 _nb) public onlyOwner {
        nbNftStake = _nb;
    }

    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    // Fonction pour "staker" des NFTs
    function stakeNFT(uint256[] calldata nftIndices) public {
        require(nftIndices.length > 0, "No NFTs to stake");
        require(nftIndices.length <= nbNftStake, "You can stake up to 3 NFTs");

        for (uint256 i = 0; i < nftIndices.length; i++) {
            uint256 nftIndex = nftIndices[i] - 1; // Soustrayez 1 pour l'index correct
            require(nftIndex < nfts.length, "Invalid NFT index");

            require(msg.sender == nfts[nftIndex].owner, "You can only stake your own NFT");
            require(!nfts[nftIndex].isStaked, "NFT is already staked");
            require(!nfts[nftIndex].isReset, "NFT is Reset");

            nfts[nftIndex].isStaked = true;
            stakedNFTCount++;
            stakedNFTsByOwner[msg.sender].push(nftIndices[i]);
            emit NftCount(msg.sender, stakedNFTCount, nftIndices[i], true);
        }

        // Vérifiez si l'utilisateur a "staké" suffisamment de NFTs
        if (stakedNFTCount >= nbNftStake) {
            hasStakedEnoughNFTs[msg.sender] = true;
            emit isAccess(true, msg.sender);
        }
    }

    // Fonction pour "déstaker" des NFTs
    function unstakeNFT(uint256[] calldata nftIndices) public {
        require(nftIndices.length > 0, "No NFTs to unstake");

        for (uint256 i = 0; i < nftIndices.length; i++) {
            uint256 nftIndex = nftIndices[i] - 1; // Soustrayez 1 pour l'index correct
            require(nftIndex < nfts.length, "Invalid NFT index");
            require(msg.sender == nfts[nftIndex].owner, "You can only unstake your own NFT");
            require(nfts[nftIndex].isStaked, "NFT is not staked");
            require(!nfts[nftIndex].isReset, "NFT is Reset");

            nfts[nftIndex].isStaked = false;
            stakedNFTCount--;

            removeNftStakeFromOwner(msg.sender, nfts[nftIndex].tokenId); // Mettez à jour ici

            emit NftCount(msg.sender, stakedNFTCount, nftIndices[i], false);
        }

        // Vérifiez si l'utilisateur a encore suffisamment de NFTs stakés
        if (stakedNFTCount < nbNftStake) {
            hasStakedEnoughNFTs[msg.sender] = false;
            emit isAccess(false, msg.sender);
        }
    }

    function getNFTLocation(
        uint256 tokenId
    ) public view onlyOwner returns (uint32 northLat, uint32 southLat, uint32 eastLon, uint32 westLon, uint tax) {
        require(tokenId >= 1 && tokenId < nextTokenId, "Invalid NFT token ID");

        uint256 nftIndex = tokenId - 1; // Soustrayez 1 pour l'index correct
        require(nftIndex < nfts.length, "Invalid NFT index");

        Location memory location = nfts[nftIndex].location;
        northLat = TFHE.decrypt(location.northLat);
        southLat = TFHE.decrypt(location.southLat);
        eastLon = TFHE.decrypt(location.eastLon);
        westLon = TFHE.decrypt(location.westLon);
        tax = nfts[nftIndex].tax;
    }

    // STAKE ACCESS FUNCTION
    function accessGeoNFTFunction(uint256 functionId) public {
        require(hasStakedEnoughNFTs[msg.sender], "You must stake 3 NFTs to access this function");
        // Appelez la fonction correspondante dans le contrat GeoNFT
    }

    function setTax(uint256 tokenId, uint256 newTax) public {
        require(msg.sender == nfts[tokenId - 1].owner, "You can only set tax for your own NFT");
        require(!nfts[tokenId - 1].isReset, "NFT is reset");
        require(!nfts[tokenId - 1].isStaked, "NFT is staked");

        nfts[tokenId - 1].tax = newTax;
    }

    //GAMING
    function checkGps(bytes calldata userLatitude, bytes calldata userLongitude) public payable returns (bool) {
        require(
            msg.value >= fees,
            string(abi.encodePacked("Frais insuffisants. Un minimum de ", fees, " MATIC est requis."))
        );

        euint32 lat = TFHE.asEuint32(userLatitude);
        euint32 lng = TFHE.asEuint32(userLongitude);
        bool result = false;
        uint tokenId = 0;

        for (uint256 i = 0; i < nfts.length; i++) {
            require(msg.sender != nfts[i].owner, "You cannot claim your own NFT");
            bool isGreaterLat = TFHE.decrypt(TFHE.ge(lat, nfts[i].location.southLat));

            bool isLessLat = TFHE.decrypt(TFHE.le(lat, nfts[i].location.northLat));
            bool isGreaterLng = TFHE.decrypt(TFHE.ge(lng, nfts[i].location.westLon));
            bool isLessLng = TFHE.decrypt(TFHE.le(lng, nfts[i].location.eastLon));

            if (isGreaterLat && isLessLat && isGreaterLng && isLessLng) {
                require(!nfts[i].claimed, "Another person own NFT");
                // Check if the user has enough funds to pay both the base fee and the NFT-specific tax
                uint256 totalTax = fees + nfts[i].tax;
                require(msg.value >= totalTax, "Insufficient funds to pay NFT tax");

                // Pay the NFT-specific tax to the previous owner
                result = true;
                address previousOwner = nfts[i].owner;
                payable(previousOwner).transfer(nfts[i].tax);
                if (nfts[i].isReset) {
                    nfts[i].isReset = false;
                    removeNftResetFromOwner(previousOwner, nfts[i].tokenId);
                    resetNFTCount--;
                    emit NFTReset(tokenId, msg.sender, false, 0);
                }
                removeNFTFromOwner(previousOwner, nfts[i].tokenId);
                nfts[i].owner = msg.sender;
                nfts[i].claimed = true;
                nfts[i].tax = 0;
                nftsByOwner[msg.sender].push(nfts[i].tokenId);
                emit NFTTransfer(previousOwner, msg.sender, nfts[i].tokenId);
                break;
            }
        }

        // Émettez l'événement pour indiquer le résultat
        emit GpsCheckResult(msg.sender, result, tokenId);

        return result;
    }

    // Fonction pour enlever un identifiant de NFT de la liste du propriétaire

    function createNFT(
        bytes[] calldata _northLat,
        bytes[] calldata _southLat,
        bytes[] calldata _eastLon,
        bytes[] calldata _westLon
    ) public onlyOwner {
        for (uint256 i = 0; i < _southLat.length; i++) {
            euint32 northLat = TFHE.asEuint32(_northLat[i]);
            euint32 southLat = TFHE.asEuint32(_southLat[i]);
            euint32 eastLon = TFHE.asEuint32(_eastLon[i]);
            euint32 westLon = TFHE.asEuint32(_westLon[i]);

            Location memory location = Location(northLat, southLat, eastLon, westLon);
            NFT memory newNFT = NFT(address(this), location, false, nextTokenId, false, false, 0);
            nfts.push(newNFT);
            nftsByOwner[address(this)].push(nextTokenId);
            nextTokenId++;
        }
    }

    function createNftForOwner(
        bytes[] calldata _northLat,
        bytes[] calldata _southLat,
        bytes[] calldata _eastLon,
        bytes[] calldata _westLon
    ) public {
        require(hasStakedEnoughNFTs[msg.sender], "The owner must stake 3 NFTs to create a new NFT");

        for (uint256 i = 0; i < _southLat.length; i++) {
            euint32 northLat = TFHE.asEuint32(_northLat[i]);
            euint32 southLat = TFHE.asEuint32(_southLat[i]);
            euint32 eastLon = TFHE.asEuint32(_eastLon[i]);
            euint32 westLon = TFHE.asEuint32(_westLon[i]);

            Location memory location = Location(northLat, southLat, eastLon, westLon);
            NFT memory newNFT = NFT(address(this), location, false, nextTokenId, false, false, 0);
            nfts.push(newNFT);
            nftsByOwner[address(this)].push(nextTokenId);
            nextTokenId++;
        }
    }

    function resetNFT(uint256[] calldata tokenIds, uint256[] calldata taxes) public {
        require(tokenIds.length > 0, "No token IDs provided");
        require(tokenIds.length == taxes.length, "Invalid input lengths");
        require(tokenIds.length == taxes.length, "Invalid input lengths");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 tax = taxes[i];

            require(tokenId >= 1 && tokenId < nextTokenId, "Invalid NFT token ID");

            uint256 nftIndex = tokenId - 1; // Soustrayez 1 pour l'index correct
            require(nftIndex < nfts.length, "Invalid NFT index");
            require(msg.sender == nfts[nftIndex].owner, "You don't own this NFT");
            require(nfts[nftIndex].claimed, "NFT need to be claimed");

            //require(!nfts[nftIndex].isStaked, "You don't stake this NFT");

            // Réinitialisez le NFT
            nfts[nftIndex].claimed = false;
            nfts[nftIndex].isReset = true;
            nfts[nftIndex].tax = tax; // Set the tax

            // Ajoutez l'identifiant du NFT reset au mapping
            resetNFTsByOwner[msg.sender].push(tokenId);
            resetNFTCount++;
            emit NFTReset(tokenId, msg.sender, true, tax);
        }

        // Vérifiez si l'utilisateur a toujours 3 NFTs stakés
        // checkStakedNFTs(msg.sender);
    }

    function claimNFT(uint256 tokenId) public {
        uint256 nftIndex = tokenId - 1; // Soustrayez 1 pour l'index correct
        require(nftIndex < nfts.length, "Invalid NFT index");
        require(msg.sender == nfts[nftIndex].owner, "You don't own this NFT");
        require(!nfts[nftIndex].isStaked, "NFT need to be unstake");
        require(nfts[nftIndex].isReset, "NFT need to be reset");

        nfts[nftIndex].claimed = true;
        nfts[nftIndex].isReset = false;
        //  nfts[nftIndex].tax = 0;
        removeNftResetFromOwner(msg.sender, tokenId);
        emit NFTReset(tokenId, msg.sender, false, 0);
        //  emit NFTTransferred(tokenId, address(0), msg.sender);
    }

    function checkStakedNFTs(address user) internal {
        uint stakedCount = 0;
        for (uint256 i = 0; i < nfts.length; i++) {
            if (nfts[i].owner == user && nfts[i].isStaked) {
                stakedCount++;
            }
        }
        bool isAccessible = stakedCount >= nbNftStake;

        if (!isAccessible) {
            hasStakedEnoughNFTs[msg.sender] = false;
            emit isAccess(false, msg.sender);
        }
    }

    // TRANSFER

    function transferNFT(address to, uint256 nftIndex) public {
        require(nftIndex < nfts.length, "Invalid NFT index");
        require(msg.sender == nfts[nftIndex].owner, "You are not the owner of this NFT");

        require(!nfts[nftIndex].isStaked, "Cannot transfer a staked NFT");
        require(!nfts[nftIndex].isReset, "Cannot transfer a Reset NFT");

        address previousOwner = nfts[nftIndex].owner;
        nfts[nftIndex].owner = to;
        nfts[nftIndex].claimed = false;

        // Supprimer l'identifiant du NFT de la liste du propriétaire précédent
        removeNFTFromOwner(previousOwner, nfts[nftIndex].tokenId);

        // Ajouter l'identifiant du NFT à la liste du nouveau propriétaire
        nftsByOwner[to].push(nfts[nftIndex].tokenId);

        emit NFTTransferred(nfts[nftIndex].tokenId, previousOwner, to);
    }

    function withdraw() public onlyOwner {
        address payable payableOwner = payable(owner);
        payableOwner.transfer(address(this).balance);
    }
}
