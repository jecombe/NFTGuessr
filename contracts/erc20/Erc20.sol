// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CoinSpace is ERC20, Ownable {
    address nftGuessr;

    event Mint(address indexed to, uint256 amount);
    event ChangeAddressGame(address indexed newAddress);
    event RecoverTokens(address indexed tokenAddress, address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    constructor(address _nftGuessr) ERC20("SpaceCoin", "SPC") {
        transferOwnership(_nftGuessr);

        // Minter le créateur initial avec un certain montant
        _mint(_nftGuessr, 10000 * 10 ** decimals());
        _mint(msg.sender, 10000 * 10 ** decimals());
    }

    // Modificateur pour n'autoriser que le contrat NFTGuessr à appeler la fonction mint
    modifier onlyNFTGuessr() {
        require(msg.sender == nftGuessr, "Only NftGuessr");
        _;
    }

    // Fonction pour permettre au propriétaire de burn des jetons
    function burn(uint256 amount, address to) external onlyOwner {
        _burn(to, amount);
        emit Burn(to, amount);
    }

    // Fonction pour permettre au propriétaire de mint de nouveaux jetons
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
        emit Mint(account, amount);
    }

    function changeAddressGame(address _newAddress) external onlyOwner {
        transferOwnership(_newAddress);

        nftGuessr = _newAddress;
        emit ChangeAddressGame(_newAddress);
    }

    // Fonction pour récupérer les jetons transférés accidentellement au contrat
    function recoverTokens(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(this), "Impossible de recup le jeton principal");
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
        emit RecoverTokens(tokenAddress, owner(), tokenAmount);
    }
}
