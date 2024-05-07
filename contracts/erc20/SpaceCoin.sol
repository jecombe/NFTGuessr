// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SpaceCoin is ERC20, Ownable {
    address nftGuessr;

    event Mint(address indexed to, uint amount);
    event ChangeAddressGame(address indexed newAddress);
    event RecoverTokens(address indexed tokenAddress, address indexed to, uint amount);
    event Burn(address indexed from, uint amount);

    constructor(address _nftGuessr, address _airdrop) ERC20("SpaceCoin", "SPC") Ownable(_nftGuessr) {
        _mint(_airdrop, 50000000 * 10 ** decimals());
        // _mint(msg.sender, 10000 * 10 ** decimals());
    }

    function burn(uint amount, address to) external onlyOwner {
        _burn(to, amount);
        emit Burn(to, amount);
    }

    function mint(address account, uint amount) external onlyOwner {
        _mint(account, amount);
        emit Mint(account, amount);
    }

    function changeAddressGame(address _newAddress) external onlyOwner {
        transferOwnership(_newAddress);

        nftGuessr = _newAddress;
        emit ChangeAddressGame(_newAddress);
    }
}
