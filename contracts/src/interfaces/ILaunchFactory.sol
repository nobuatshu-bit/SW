// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {LaunchTypes} from "../libraries/LaunchTypes.sol";

/// @title ILaunchFactory
/// @notice External interface for the LaunchFactory contract.
/// @dev Consumers (e.g. the backend indexer, frontend SDK, integration tests)
///      should program against this interface rather than the concrete contract.
interface ILaunchFactory {
    // ── Mutating ─────────────────────────────────────────────────────────────

    /// @notice Deploys a new Launch clone and registers it in the factory registry.
    /// @param params Launch configuration submitted by the creator.
    /// @return launch Address of the newly deployed Launch clone.
    function createLaunch(LaunchTypes.LaunchParams calldata params)
        external
        returns (address launch);

    /// @notice Pauses new launch creation. Existing launches are unaffected.
    function pause() external;

    /// @notice Resumes new launch creation.
    function unpause() external;

    /// @notice Updates the protocol fee applied to future launches.
    /// @param newFeeBps New fee in basis points. Must not exceed MAX_PROTOCOL_FEE_BPS.
    function setProtocolFee(uint16 newFeeBps) external;

    /// @notice Updates the address that receives protocol fees on future launches.
    /// @param newFeeRecipient Non-zero recipient address.
    function setFeeRecipient(address newFeeRecipient) external;

    /// @notice Replaces the Launch implementation cloned by future createLaunch calls.
    /// @param newImplementation Address of a deployed contract with bytecode.
    function setLaunchImplementation(address newImplementation) external;

    /// @notice Called by a registered Launch clone when it reaches a terminal state.
    ///         Decrements the creator's active launch count.
    function noteTerminal() external;

    // ── Views ─────────────────────────────────────────────────────────────────

    /// @notice Returns the current protocol fee in basis points.
    function protocolFeeBps() external view returns (uint16);

    /// @notice Returns the current fee recipient address.
    function feeRecipient() external view returns (address);

    /// @notice Returns the Launch implementation address cloned by new launches.
    function launchImplementation() external view returns (address);

    /// @notice Returns the total number of launches ever created by this factory.
    function launchCount() external view returns (uint256);

    /// @notice Returns the launch address at a zero-based global index.
    /// @param index Zero-based position in the global launch registry.
    function launchAt(uint256 index) external view returns (address);

    /// @notice Returns the immutable LaunchRecord stored for a given launch address.
    /// @param launch Address of a Launch clone created by this factory.
    function getLaunchRecord(address launch)
        external
        view
        returns (LaunchTypes.LaunchRecord memory);

    /// @notice Returns all launch addresses created by a specific creator.
    /// @param creator Address whose launches are being queried.
    function getLaunchesByCreator(address creator)
        external
        view
        returns (address[] memory);

    /// @notice Returns the number of active (non-terminal) launches for a creator.
    /// @param creator Address to query.
    function getActiveLaunchCount(address creator) external view returns (uint256);

    /// @notice Returns whether an address was deployed and registered by this factory.
    /// @param launch Address to check.
    function isRegistered(address launch) external view returns (bool);
}
