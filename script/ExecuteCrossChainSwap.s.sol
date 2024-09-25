// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {CrossChainSwap} from "src/CrossChainSwap.sol";
import {CrossChainVesting} from "src/CrossChainVesting.sol";
import {ArtcoinBEP20} from "src/token/ArtcoinBEP20.sol";
import {Constants} from "src/libs/Constants.sol";
import {Enums} from "src/libs/Enums.sol";
import {AmoyConfig} from "config/AmoyConfig.sol";
import {BnbConfig} from "config/BnbConfig.sol";

interface LzEndpoint {
    function retryPayload(uint16 _srcChainId, bytes calldata _srcAddress, bytes calldata _payload) external;
    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external;
}

contract ExecuteCrossChainSwapScript is Script {
    address swapContract;
    address vestingContract;
    address deployerPublicKey;
    uint256 deployerPrivateKey;
    address artcoinBEP20;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        swapContract = BnbConfig.CROSS_CHAIN_SWAP;
        artcoinBEP20 = BnbConfig.ARTCOIN_BEP20;
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 swapAmount = 5000 ether;

        // 1. SwapOptions.OPTION1
        ArtcoinBEP20(artcoinBEP20).claim();
        ArtcoinBEP20(artcoinBEP20).approve(address(swapContract), swapAmount);

        uint256 balanceBefore = ArtcoinBEP20(artcoinBEP20).balanceOf(deployerPublicKey);
        assert(balanceBefore > 0);

        bytes memory payload = abi.encode(deployerPublicKey, swapAmount, Enums.SwapOptions.OPTION3);
        uint256 nativeFee = CrossChainSwap(swapContract).estimateLzSendFees(payload);
        assert(nativeFee > 0);

        CrossChainSwap(swapContract).swap{value: nativeFee}(Enums.SwapOptions.OPTION1);


        // 2. SwapOptions.OPTION2
        ArtcoinBEP20(artcoinBEP20).claim();
        ArtcoinBEP20(artcoinBEP20).approve(address(swapContract), swapAmount);

        payload = abi.encode(deployerPublicKey, swapAmount, Enums.SwapOptions.OPTION3);
        nativeFee = CrossChainSwap(swapContract).estimateLzSendFees(payload);
        assert(nativeFee > 0);

        CrossChainSwap(swapContract).swapAmount{value: nativeFee}(swapAmount, Enums.SwapOptions.OPTION2);


        // 3. SwapOptions.OPTION3
        ArtcoinBEP20(artcoinBEP20).claim();
        ArtcoinBEP20(artcoinBEP20).approve(address(swapContract), swapAmount);

        payload = abi.encode(deployerPublicKey, swapAmount, Enums.SwapOptions.OPTION3);
        nativeFee = CrossChainSwap(swapContract).estimateLzSendFees(payload);
        assert(nativeFee > 0);

        CrossChainSwap(swapContract).swapAmount{value: nativeFee}(swapAmount, Enums.SwapOptions.OPTION3);

        vm.stopBroadcast();
    }
}
