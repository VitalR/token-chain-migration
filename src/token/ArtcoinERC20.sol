// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {ERC20Burnable} from "@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Capped, ERC20} from "@openzeppelin/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Permit} from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/access/Ownable2Step.sol";

/// @title Artcoin Token Contract
/// @notice ERC20 token with capped supply, burnable functionality, and role-based minting and burning.
/// @dev Inherits functionality from OpenZeppelin's ERC20Capped, ERC20Burnable, ERC20Permit and Ownable2Step contracts.
contract Artcoin is ERC20Burnable, ERC20Capped, ERC20Permit, Ownable2Step, AccessControl {
    /// @notice Define a constant for the minter role.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Define a constant for the burner role.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Sets up the ERC20 token with a name and symbol, and assigns ownership to the owner account.
    /// @param _owner The address of the owner account.
    constructor(address _owner)
        ERC20("ARTCOIN", "ART")
        ERC20Permit("ARTCOIN")
        ERC20Capped(5_000_000_000 * 10 ** 18)
        Ownable2Step()
        Ownable(_owner)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(MINTER_ROLE, _owner);
        _grantRole(BURNER_ROLE, _owner);
    }

    /// @notice Mints tokens to the specified address.
    /// @dev Callable by owner or accounts with MINTER_ROLE.
    /// @param _to The address to mint tokens to.
    /// @param _amount The amount of tokens to mint.
    function mint(address _to, uint256 _amount) external onlyRole(MINTER_ROLE) returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    /// @notice Burns a specific amount of tokens.
    /// @dev Callable by owner or accounts with BURNER_ROLE.
    /// @param _amount The number of tokens to burn.
    function burn(uint256 _amount) public override onlyRole(BURNER_ROLE) {
        _burn(msg.sender, _amount);
    }

    /// @notice Burns tokens from the specified address.
    /// @dev Callable by owner or accounts with BURNER_ROLE.
    /// @param _from The address to burn tokens from.
    /// @param _amount The amount of tokens to burn.
    function burnFrom(address _from, uint256 _amount) public override onlyRole(BURNER_ROLE) {
        super.burnFrom(_from, _amount);
    }

    /// @notice Checks if the specified account has the MINTER_ROLE.
    /// @param account The address to check.
    /// @return True if the account has the MINTER_ROLE, false otherwise.
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    /// @notice Updates the state when tokens are transferred.
    /// @dev Overrides the _update function from ERC20 and ERC20Capped.
    /// @param from The address transferring tokens.
    /// @param to The address receiving tokens.
    /// @param value The amount of tokens being transferred.
    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Capped) {
        super._update(from, to, value);

        if (from == address(0)) {
            uint256 maxSupply = cap();
            uint256 supply = totalSupply();
            if (supply > maxSupply) {
                revert ERC20ExceededCap(supply, maxSupply);
            }
        }
    }
}
