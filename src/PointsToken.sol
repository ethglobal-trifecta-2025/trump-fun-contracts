// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PointsToken is ERC20, Ownable {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimalsValue, uint256 initialSupply)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        _decimals = decimalsValue;
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
