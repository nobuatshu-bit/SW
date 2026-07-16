// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {LaunchTypes} from "../libraries/LaunchTypes.sol";

library SherwoodErrors {
    error AlreadyInitialized();
    error BelowMinContribution(uint256 sent, uint256 minimum);
    error CliffNotReached();
    error EnforcedPause();
    error ExpectedPause();
    error InvalidAddress();
    error InvalidDuration();
    error InvalidFeeBps(uint256 feeBps);
    error InvalidLaunchConfiguration();
    error InvalidLaunchDuration();
    error InvalidPaymentAmount();
    error InvalidTokenAmount();
    error InvalidProjectState(LaunchTypes.ProjectState currentState);
    error MaxContributionExceeded(uint256 newTotal, uint256 maximum);
    error MaximumRaiseExceeded();
    error NativeTransferFailed();
    error NoClaimableBalance();
    error NoVestedTokens();
    error NoWithdrawableBalance();
    error SaleAlreadyEnded();
    error SaleEnded();
    error SaleNotActive();
    error SaleNotFinished();
    error SaleNotStarted();
    error SaleNotLive();
    error ScheduleAlreadyExists(address beneficiary);
    error ScheduleNotFound(address beneficiary);
    error ScheduleRevoked(address beneficiary);
    error TokenAllocationExceeded();
    error TooManyActiveLaunches(address creator, uint256 limit);
    error Unauthorized();
    error UnauthorizedFactory();
}
