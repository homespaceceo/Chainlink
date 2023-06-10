// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("USDT", "USDT") {
        _mint(msg.sender, 100_000e6);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
