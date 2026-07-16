// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {LaunchTypes} from "../libraries/LaunchTypes.sol";

library SherwoodErrors {
    error AlreadyInitialized();
    error EnforcedPause();
    error ExpectedPause();
    error InvalidAddress();
    error InvalidFeeBps(uint256 feeBps);
    error InvalidLaunchConfiguration();
    error InvalidLaunchDuration();
    error InvalidPaymentAmount();
    error InvalidTokenAmount();
    error InvalidProjectState(LaunchTypes.ProjectState currentState);
    error MaximumRaiseExceeded();
    error NativeTransferFailed();
    error NoClaimableBalance();
    error NoWithdrawableBalance();
    error SaleAlreadyEnded();
    error SaleEnded();
    error SaleNotFinished();
    error SaleNotStarted();
    error SaleNotLive();
    error TokenAllocationExceeded();
    error TooManyActiveLaunches(address creator, uint256 limit);
    error Unauthorized();
    error UnauthorizedFactory();
}
