// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {LaunchTypes} from "../libraries/LaunchTypes.sol";

/// @title ILaunch
/// @notice Minimal interface that LaunchFactory requires from each deployed Launch clone.
/// @dev The full Launch implementation (next sprint) must satisfy this interface.
///      Keeping it minimal reduces the coupling between the factory and the launch
///      contract, allowing the implementation to evolve independently.
interface ILaunch {
    /// @notice One-time initializer called by the factory immediately after cloning.
    /// @param factory_       Address of the deploying LaunchFactory.
    /// @param creator_       Address of the launch creator.
    /// @param token_         ERC-20 token address participants will receive.
    /// @param feeRecipient_  Address that will collect the protocol fee.
    /// @param protocolFeeBps Protocol fee in basis points applied to raised funds.
    /// @param params         Full launch configuration supplied by the creator.
    function initialize(
        address factory_,
        address creator_,
        address token_,
        address feeRecipient_,
        uint16 protocolFeeBps,
        LaunchTypes.LaunchParams calldata params
    ) external;
}
