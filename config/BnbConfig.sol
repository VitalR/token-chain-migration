// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @notice Latest configuration of deployed contracts
library BnbConfig {
    uint256 public constant TESTNET_CHAIN_ID = 97;

    address public constant ARTCOIN_BEP20 = 0xF3B5E392278C3Ff61C5E6eBE14aC9EB5EdEb976a;

    address public constant CROSS_CHAIN_SWAP = 0x297571610EEB63136a796fC717952017BC3A6774;

    // The LayerZero endpoint instance.
    address public constant LZ_BNB_ENDPOINT = 0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1;
    // The destination chain ID for cross-chain swaps.
    uint16 public constant LZ_BNB_DEST_CHAIN_ID = 10102;
}
