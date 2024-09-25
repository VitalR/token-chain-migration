// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @notice Latest configuration of deployed contracts
library AmoyConfig {
    uint256 public constant CHAIN_ID = 80002;

    address public constant ARTCOIN_ERC20 = 0x234aFAFa5507042BD05D8f42454616BA103004B1;

    address public constant CROSS_CHAIN_VESTING = 0xE3351140F9D2060Df71B458657099beA83b095C0;

    // The LayerZero endpoint instance.
    address public constant LZ_POL_ENDPOINT = 0x55370E0fBB5f5b8dAeD978BA1c075a499eB107B8;
    // The destination chain ID for cross-chain swaps.
    uint16 public constant LZ_POL_DEST_CHAIN_ID = 10267;
}
