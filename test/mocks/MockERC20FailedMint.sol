// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract MockERC20FailedMint is ERC20 {
    error UnableToMint();

    constructor() ERC20("MockERC20", "MockERC20") {}

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function claim() public {
        _update(address(0), msg.sender, 5000 ether);
    }

    function mint(address, uint256) public pure returns (bool) {
        // revert UnableToMint();
        // _mint(account, amount);
        return false;
    }

    function burn(address from, uint256 value) public returns (bool) {
        _burn(from, value);
        return true;
    }
}
