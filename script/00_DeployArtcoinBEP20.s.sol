// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {ArtcoinBEP20} from "src/token/ArtcoinBEP20.sol";

contract DeployArtcoinBEP20Script is Script {
    ArtcoinBEP20 token;
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

        token = new ArtcoinBEP20("ARTCOIN_OLD", "ART");
        console2.log("==token addr=%s", address(token));

        vm.stopBroadcast();
    }
}
