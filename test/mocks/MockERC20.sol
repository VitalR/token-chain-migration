// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockERC20", "MockERC20") {}

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function mint(address account, uint256 amount) public returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(address from, uint256 value) public returns (bool) {
        _burn(from, value);
        return true;
    }
}
