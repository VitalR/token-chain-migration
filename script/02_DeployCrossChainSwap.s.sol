// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {CrossChainSwap} from "src/CrossChainSwap.sol";
import {AmoyConfig} from "config/AmoyConfig.sol";
import {BnbConfig} from "config/BnbConfig.sol";

contract DeployCrossChainSwapScript is Script {
    CrossChainSwap swapContract;
    address owner;
    address deployerPublicKey;
    uint256 deployerPrivateKey;
    address artcoinBEP20;
    uint128 swapStartTime;
    uint128 swapEndTime;
    address lzEndpoint;
    uint16 destChainId;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        owner = vm.envAddress("OWNER_PUBLIC_KEY");
        artcoinBEP20 = BnbConfig.ARTCOIN_BEP20;
        lzEndpoint = BnbConfig.LZ_BNB_ENDPOINT;
        destChainId = AmoyConfig.LZ_POL_DEST_CHAIN_ID;
        swapStartTime = 1726659000;
        swapEndTime = 1730411999;
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        swapContract = new CrossChainSwap(deployerPublicKey, artcoinBEP20, lzEndpoint, destChainId);
        console2.log("==swapContract addr=%s", address(swapContract));

        CrossChainSwap(swapContract).setSwapWindow(swapStartTime, swapEndTime);

        vm.stopBroadcast();
    }
}
