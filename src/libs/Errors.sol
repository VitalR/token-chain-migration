// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title Errors Library
/// @notice Provides custom error messages for use in Philcoin cross-chain contracts.
library Errors {
    /// @notice Thrown when there are no tokens available to swap.
    error NothingToSwap();

    /// @notice Thrown when a zero address is provided where a non-zero address is required.
    error ZeroAddressProvided();

    /// @notice Thrown when the amount to swap is greater than the available balance.
    error InsufficientAmountToSwap();

    /// @notice Thrown when an unsupported swap option is selected.
    error UnsupportedSwapOption();

    /// @notice Thrown when there are no tokens available to release.
    error NoTokensToRelease();

    /// @notice Thrown when the platform fee is set too high.
    error FeeTooHigh();

    /// @notice Thrown when token minting fails.
    error MintFailed();

    /// @notice Thrown when the amount to swap is below the minimum threshold required for a swap operation.
    error AmountBelowMinimumSwapThreshold();

    /// @notice Thrown when an operation requires a positive non-zero value but received zero instead.
    error NeedsMoreThanZero();

    /// @notice Thrown when the source address of a cross-chain message is not recognized or trusted.
    error UntrustedSourceAddress();

    /// @notice Thrown when the swap times (start or end) are not set.
    error SwapTimesNotSet();

    /// @notice Thrown when the swap period is not active.
    error SwapPeriodNotActive();

    /// @notice Thrown when the end time is set to a value in the past.
    error EndTimeInPast();

    /// @notice Thrown when the start time must be before the end time.
    error StartTimeMustBeBeforeEndTime();

    /// @notice Thrown when an invalid vesting timestamp is provided.
    error InvalidVestingTimestamp();

    /// @notice Thrown when attempting to release tokens before the vesting period has started.
    error VestingNotStartedYet();

    /// @notice Thrown when attempting to release tokens before the cliff period has ended.
    error CliffPeriodNotReached();

    /// @notice Thrown when attempting to perform the initial release before the start of the vesting period (TGE).
    error InitialReleaseNotStartedYet();

    /// @notice Thrown when attempting to perform the initial release after it has already been done.
    error InitialReleaseAlreadyDone();

    /// @notice Thrown when there are no tokens available to claim.
    error NoTokensToClaim();

    /// @notice Thrown when attempting to perform the initial claim before the start of the vesting period (TGE).
    error InitialClaimNotStartedYet();

    /// @notice Thrown when no excess tokens are available for withdrawal.
    error NoExcessTokensAvailableForWithdrawal();

    /// @notice Thrown when the requested withdrawal amount exceeds the available excess tokens.
    error RequestedAmountExceedsAvailableExcess();
}
