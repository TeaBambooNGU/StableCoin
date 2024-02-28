// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import {ERC20,ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TangStableCoin is ERC20, ERC20Burnable, Ownable {

    event TangStableCoin_Mint(address indexed to, uint256 amount);
    event TangStableCoin_Burn(address indexed account, uint256 amount);

    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {
        
    }
    /**
     * 只提供给稳定币引擎合约调用，其他用户铸造稳定币
     * @param to 铸造的地址
     * @param amount 销毁的数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit TangStableCoin_Mint(to, amount);
    }
    /**
     * 只提供给稳定币引擎合约调用，不容许用户销毁token
     * @param account 被销毁token的地址
     * @param value 销毁的数量
     */
    function burnFrom(address account, uint256 value) public override onlyOwner {
        _burn(account, value);
        emit TangStableCoin_Burn(account, value);
    }
    /**
     * 销毁稳定币引擎自己的稳定币
     * @param value 销毁的数量
     */
    function burn(uint256 value) public override onlyOwner {
        _burn(_msgSender(), value);
    }


}