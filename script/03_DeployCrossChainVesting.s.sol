// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {CrossChainVesting} from "src/CrossChainVesting.sol";
import {AmoyConfig} from "config/AmoyConfig.sol";
import {BnbConfig} from "config/BnbConfig.sol";

contract DeployCrossChainVestingScript is Script {
    CrossChainVesting vestingContract;
    address owner;
    address feeReceiver;
    address deployerPublicKey;
    uint256 deployerPrivateKey;
    address artcoinERC20;
    address lzEndpoint;
    uint16 srcChainId;
    uint32 swapCloseTime;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        owner = vm.envAddress("OWNER_PUBLIC_KEY");
        feeReceiver = vm.envAddress("FEE_RECEIVER_PUBLIC_KEY");
        artcoinERC20 = AmoyConfig.ARTCOIN_ERC20;
        lzEndpoint = AmoyConfig.LZ_POL_ENDPOINT;
        srcChainId = BnbConfig.LZ_BNB_DEST_CHAIN_ID;
        swapCloseTime = 1730411999;
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        vestingContract = new CrossChainVesting(
            deployerPublicKey, artcoinERC20, lzEndpoint, srcChainId, 25_00, 50_00, deployerPublicKey, swapCloseTime
        );
        console2.log("==vestingContract addr=%s", address(vestingContract));

        vm.stopBroadcast();
    }
}
