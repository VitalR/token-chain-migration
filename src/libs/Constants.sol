// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title Constants Library
/// @dev Provides constants for use across different contracts or functions within a project.
library Constants {
    /// @notice Maximum basis points used for fee calculations, representing a percentage as a whole number.
    /// @dev 10,000 basis points is equivalent to 100%, used in financial calculations.
    uint256 internal constant MAX_BPS = 100_00;

    /// @notice Number of seconds in three months, used for extended time-related calculations.
    /// @dev This constant provides a convenient reference for time periods less than a year (approximately 7,889,238 seconds or 91.31 days).
    uint256 internal constant SECONDS_PER_THREE_MONTHS = 7_889_238;

    /// @notice Number of seconds in half a year, used for extended time-related calculations.
    /// @dev This constant provides a convenient reference for time periods less than a year (approximately 15,778,476 seconds or 182.62 days).
    uint256 internal constant SECONDS_PER_HALF_YEAR = 15_778_476;

    /// @notice Number of seconds in a Gregorian year, used for time-related calculations.
    /// @dev This constant is based on the average length of a year accounting for leap years (approximately 31,556,952 seconds or 365.2425 days).
    uint256 internal constant SECONDS_PER_YEAR = 31_556_952;

    /// @notice Number of seconds in a year and a half, used for extended time-related calculations.
    /// @dev This constant provides a convenient reference for time periods longer than a year (approximately 47,335,428 seconds or 547.86 days).
    uint256 internal constant SECONDS_PER_YEAR_AND_HALF = 47_335_428;

    /// @notice Number of seconds in two years.
    /// @dev This constant provides a convenient reference for time periods longer than a year (approximately 63,113,904 seconds or 730.485 days).
    uint256 public constant SECONDS_PER_TWO_YEARS = 63_113_904;

    /// @notice Address used to represent a "burn" or "black hole" where tokens can be sent to be permanently removed from circulation.
    /// @dev This is a commonly used practice in token economics to reduce the supply or remove tokens from use.
    address internal constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
}
