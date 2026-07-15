// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {LaunchTypes} from "../libraries/LaunchTypes.sol";

library SherwoodErrors {
    error AlreadyInitialized();
    error InvalidAddress();
    error InvalidFeeBps(uint256 feeBps);
    error InvalidLaunchConfiguration();
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
    error Unauthorized();
    error UnauthorizedFactory();
}
