// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IERC677Receiver {
  function onTokenTransfer(address _sender, uint _value, bytes memory _data) external;
}

contract MockLinkToken is ERC20, Ownable {
    using Address for address;

    constructor() ERC20("MockLink", "MLINK") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function transferAndCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool success) {
        success = transfer(to, value);
        if (to.isContract()) {
            IERC677Receiver receiver = IERC677Receiver(to);
            receiver.onTokenTransfer(_msgSender(), value, data);
        }
    }
}
