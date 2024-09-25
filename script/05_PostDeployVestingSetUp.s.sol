// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {CrossChainVesting} from "src/CrossChainVesting.sol";
import {AmoyConfig} from "config/AmoyConfig.sol";
import {BnbConfig} from "config/BnbConfig.sol";

contract PostDeployVestingSetUpScript is Script {
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
        // lzEndpoint = AmoyConfig.LZ_POL_ENDPOINT;
        destChainId = BnbConfig.LZ_BNB_DEST_CHAIN_ID;
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        CrossChainVesting(vestingContract).setTrustedRemoteAddress(destChainId, abi.encodePacked(address(swapContract)));
        assert(
            CrossChainVesting(vestingContract).isTrustedRemote(
                destChainId, abi.encodePacked(address(swapContract), address(vestingContract))
            ) == true
        );
        vm.stopBroadcast();
    }
}
