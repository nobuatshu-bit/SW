// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library LaunchConstants {
    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint16  internal constant MAX_PROTOCOL_FEE_BPS = 1_000;
    uint256 internal constant WAD = 1e18;

    /// @dev Maximum concurrent active (non-completed, non-cancelled) launches a single
    ///      creator may own. Prevents spam and limits indexer surface area.
    uint256 internal constant MAX_LAUNCHES_PER_CREATOR = 3;

    /// @dev Maximum vesting duration: 4 years in seconds.
    uint64 internal constant MAX_VESTING_DURATION = 4 * 365 days;
}
