// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {CrossChainSwap} from "src/CrossChainSwap.sol";
import {AmoyConfig} from "config/AmoyConfig.sol";
import {BnbConfig} from "config/BnbConfig.sol";

contract PostDeploySwapSetUpScript is Script {
    address swapContract;
    address vestingContract;
    address deployerPublicKey;
    uint256 deployerPrivateKey;
    address lzEndpoint;
    uint16 destChainId;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        swapContract = BnbConfig.CROSS_CHAIN_SWAP;
        vestingContract = AmoyConfig.CROSS_CHAIN_VESTING;
        lzEndpoint = AmoyConfig.LZ_POL_ENDPOINT;
        destChainId = AmoyConfig.LZ_POL_DEST_CHAIN_ID;
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        CrossChainSwap(swapContract).setTrustedRemoteAddress(destChainId, abi.encodePacked(address(vestingContract)));
        assert(
            CrossChainSwap(swapContract).isTrustedRemote(
                destChainId, abi.encodePacked(address(vestingContract), address(swapContract))
            ) == true
        );
        vm.stopBroadcast();
    }
}
