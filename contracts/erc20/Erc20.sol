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

    constructor(address _nftGuessr, address _airdrop) ERC20("SpaceCoin", "SPC") {
        transferOwnership(_nftGuessr);

        // Minter le créateur initial avec un certain montant
        _mint(_airdrop, 50000000 * 10 ** decimals());
        // _mint(msg.sender, 10000 * 10 ** decimals());
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
}
