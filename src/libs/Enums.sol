// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title Enums Library
/// @dev Library defining different swap options for PHILCoin (PHL) holders following a smart contract update.
library Enums {
    /// @notice Enum for swap options available to PHILCoin holders.
    /// @dev The following options are available:
    ///      - OPTION1: 12-month lock-up period with a 25% bonus.
    ///      - OPTION2: 18-month lock-up period with a 50% bonus.
    ///      - OPTION3: 1:1 swap with no lock-up and no bonuses, tokens are claimable after the Token Generation Event (TGE).
    enum SwapOptions {
        OPTION1, // Swap with a 12-month lock-up period and a 25% bonus.
        OPTION2, // Swap with an 18-month lock-up period and a 50% bonus.
        OPTION3  // Swap with no lock-up or bonus, tokens are transferred 1:1 and claimable after TGE.
    }
}
