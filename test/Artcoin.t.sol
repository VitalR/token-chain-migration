// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, stdError, console2} from "@forge-std/Test.sol";
import {Artcoin} from "src/token/ArtcoinERC20.sol";
import {Errors} from "src/libs/Errors.sol";

contract ArtcoinUnitTest is Test {
    Artcoin token;
    address owner;

    bytes32 PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        owner = makeAddr("owner");
        token = new Artcoin(owner);
    }

    function test_setUpState() public view {
        assertEq(token.name(), "ARTCOIN");
        assertEq(token.symbol(), "ART");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.cap(), 5_000_000_000 * 10 ** 18);
        assertEq(token.owner(), owner);
        assertEq(token.nonces(owner), 0);
    }

    function test_deploy_reverts() public {
        vm.expectRevert(); //OwnableInvalidOwner(0x0000000000000000000000000000000000000000)
        token = new Artcoin(address(0));
    }

    function test_mint_by_owner() public {
        assertEq(token.balanceOf(owner), 0);
        assertEq(token.totalSupply(), 0 ether);
        vm.prank(owner);
        token.mint(owner, 1 ether);
        assertEq(token.balanceOf(owner), 1 ether);
        assertEq(token.totalSupply(), 1 ether);
    }

    function test_mintCap_by_owner() public {
        assertEq(token.balanceOf(owner), 0);
        assertEq(token.totalSupply(), 0 ether);
        vm.prank(owner);
        token.mint(owner, 5_000_000_000 * 10 ** 18);
        assertEq(token.balanceOf(owner), 5_000_000_000 ether);
        assertEq(token.totalSupply(), 5_000_000_000 ether);
    }

    function test_mintCap_by_minter() public {
        assertFalse(token.isMinter(address(this)));
        bytes32 role = token.MINTER_ROLE();
        vm.prank(owner);
        token.grantRole(role, address(this));
        assertTrue(token.isMinter(address(this)));

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.totalSupply(), 0 ether);
        vm.prank(address(this));
        token.mint(address(this), 5_000_000_000 * 10 ** 18);
        assertEq(token.balanceOf(address(this)), 5_000_000_000 ether);
        assertEq(token.totalSupply(), 5_000_000_000 ether);
    }

    function test_mint_reverts() public {
        assertEq(token.balanceOf(address(this)), 0);
        vm.prank(address(this));
        vm.expectRevert(); //Unauthorized()
        token.mint(address(this), 1 ether);
        assertEq(token.balanceOf(owner), 0 ether);
        assertEq(token.totalSupply(), 0 ether);
        bytes32 role = token.MINTER_ROLE();
        vm.startPrank(owner);
        vm.expectRevert(); //ERC20ExceededCap
        token.mint(owner, 5_000_000_001 * 10 ** 18);
        token.grantRole(role, address(this));
        vm.stopPrank();
        vm.prank(address(this));
        vm.expectRevert(); //ERC20ExceededCap
        token.mint(address(this), 5_000_000_001 * 10 ** 18);
    }

    function test_grantRole() public {
        assertFalse(token.isMinter(address(this)));
        bytes32 role = token.MINTER_ROLE();
        vm.prank(owner);
        token.grantRole(role, address(this));
        assertTrue(token.isMinter(address(this)));
    }

    function test_grantRole_reverts() public {
        assertFalse(token.isMinter(address(this)));
        bytes32 role = token.MINTER_ROLE();
        vm.prank(address(this));
        vm.expectRevert(); //Unauthorized()
        token.grantRole(role, address(this));
        assertFalse(token.isMinter(address(this)));
    }

    function test_revokeRole() public {
        test_grantRole();
        assertTrue(token.isMinter(address(this)));
        bytes32 role = token.MINTER_ROLE();
        vm.prank(owner);
        token.revokeRole(role, address(this));
        assertFalse(token.isMinter(address(this)));
    }

    function test_revokeRole_reverts() public {
        test_grantRole();
        assertTrue(token.isMinter(address(this)));
        bytes32 role = token.MINTER_ROLE();
        vm.prank(address(this));
        vm.expectRevert(); //Unauthorized()
        token.revokeRole(role, address(this));
        assertTrue(token.isMinter(address(this)));
    }

    function test_transfer() public {
        test_mint_by_owner();
        assertEq(token.balanceOf(owner), 1 ether);
        assertEq(token.totalSupply(), 1 ether);
        vm.prank(owner);
        vm.expectRevert(); //ERC20InvalidReceiver
        token.transfer(address(0), 0.5 ether);
        assertEq(token.balanceOf(owner), 1 ether);
        assertEq(token.totalSupply(), 1 ether);
    }

    function test_burn() public {
        test_mint_by_owner();
        assertEq(token.balanceOf(owner), 1 ether);
        assertEq(token.totalSupply(), 1 ether);
        vm.startPrank(owner);
        token.approve(owner, 0.5 ether);
        token.burn(0.5 ether);
        vm.stopPrank();
        assertEq(token.balanceOf(owner), 0.5 ether);
        assertEq(token.totalSupply(), 0.5 ether);
        vm.prank(address(this));
        vm.expectRevert(); //AccessControlUnauthorizedAccount()
        token.burn(0.5 ether);
        assertEq(token.totalSupply(), 0.5 ether);
    }

    function test_burnFrom() public {
        test_mint_by_owner();
        assertEq(token.balanceOf(owner), 1 ether);
        assertEq(token.totalSupply(), 1 ether);
        vm.startPrank(owner);
        token.approve(owner, 0.5 ether);
        token.burnFrom(owner, 0.5 ether);
        vm.stopPrank();
        assertEq(token.balanceOf(owner), 0.5 ether);
        assertEq(token.totalSupply(), 0.5 ether);
    }

    function test_burnFrom_by_burnerRole() public {
        test_mint_by_owner();
        assertEq(token.balanceOf(owner), 1 ether);
        assertEq(token.totalSupply(), 1 ether);
        bytes32 role = token.BURNER_ROLE();
        vm.startPrank(owner);
        token.grantRole(role, address(this));
        token.approve(address(this), 1 ether);
        vm.stopPrank();
        vm.prank(address(this));
        token.burnFrom(owner, 1 ether);
        assertEq(token.balanceOf(owner), 0 ether);
        assertEq(token.totalSupply(), 0 ether);
    }

    function test_burnFrom_reverts() public {
        test_mint_by_owner();
        assertEq(token.balanceOf(owner), 1 ether);
        assertEq(token.totalSupply(), 1 ether);
        vm.prank(address(this));
        vm.expectRevert(); //Unauthorized()
        token.burnFrom(owner, 0.5 ether);
        assertEq(token.balanceOf(owner), 1 ether);
        assertEq(token.totalSupply(), 1 ether);
        vm.prank(owner);
        token.mint(address(this), 1 ether);
        assertEq(token.balanceOf(address(this)), 1 ether);
        assertEq(token.totalSupply(), 2 ether);
        vm.prank(owner);
        vm.expectRevert(); //ERC20InsufficientAllowance
        token.burnFrom(address(this), 1 ether);
        assertEq(token.balanceOf(address(this)), 1 ether);
        assertEq(token.totalSupply(), 2 ether);
    }

    function test_permit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        assertEq(token.allowance(owner, address(0xCAFE)), 1e18);
        assertEq(token.nonces(owner), 1);
    }

    function test_permit_reverts_WhenPastDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp - 1))
                )
            )
        );
        vm.expectRevert(); // ERC2612ExpiredSignature
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp - 1, v, r, s);
    }

    function test_permit_reverts_BadNonce() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 1, block.timestamp))
                )
            )
        );
        vm.expectRevert(); //ERC2612InvalidSigner
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function test_permit_reverts_BadDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );
        vm.expectRevert(); //ERC2612InvalidSigner
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp + 1, v, r, s);
    }

    function test_permit_reverts_Replay() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        vm.expectRevert(); //ERC2612InvalidSigner
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function test_transferOwnership() public {
        // Ensure the initial owner is correctly set
        assertEq(token.owner(), owner);

        // Try to transfer ownership from an unauthorized address (should revert)
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert(); //OwnableUnauthorizedAccount
        token.transferOwnership(notOwner);

        // Try to accept ownership from the new owner before initiating (should revert)
        address newOwner = makeAddr("newOwner");
        vm.prank(newOwner);
        vm.expectRevert(); //OwnableUnauthorizedAccount
        token.acceptOwnership();

        // Initiate ownership transfer from the owner
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferStarted(owner, newOwner);
        token.transferOwnership(newOwner);

        // Ensure the pending owner is set correctly
        assertEq(token.pendingOwner(), newOwner);

        // Try to accept ownership from a non-candidate address (should revert)
        vm.prank(notOwner);
        vm.expectRevert(); //OwnableUnauthorizedAccount
        token.acceptOwnership();

        // Accept ownership transfer from the new owner
        vm.prank(newOwner);
        token.acceptOwnership();

        // Ensure the new owner is correctly set
        assertEq(token.owner(), newOwner);

        // Ensure pending owner is reset
        assertEq(token.pendingOwner(), address(0));

        // Try to renounce ownership from the new owner
        vm.prank(newOwner);
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(newOwner, address(0));
        token.renounceOwnership();

        // Ensure ownership is now renounced
        assertEq(token.owner(), address(0));
    }
}
