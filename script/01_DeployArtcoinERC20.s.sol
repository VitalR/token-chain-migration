// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {Artcoin} from "src/token/ArtcoinERC20.sol";

contract DeployArtcoinScript is Script {
    Artcoin token;
    address owner;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        owner = vm.envAddress("OWNER_PUBLIC_KEY");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        token = new Artcoin(deployerPublicKey);
        console2.log("==token addr=%s", address(token));

        vm.stopBroadcast();
    }
}
