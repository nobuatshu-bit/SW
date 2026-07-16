// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {SherwoodErrors} from "../errors/SherwoodErrors.sol";
import {SherwoodEvents} from "../events/SherwoodEvents.sol";
import {ILaunchProject} from "../interfaces/ILaunchProject.sol";
import {LaunchTypes} from "../libraries/LaunchTypes.sol";
import {SherwoodToken} from "../token/SherwoodToken.sol";
import {LaunchConstants} from "../utils/LaunchConstants.sol";

/// @title  SherwoodFactory
/// @notice Deploys launch tokens and gas-efficient EIP-1167 LaunchProject clones.
///
/// @dev    Architecture
///         ─────────────
///         SherwoodFactory is the single entry point for creating a SHERWOOD launch
///         on the V1 (fixed-price) path. It:
///           1. Validates the creator-supplied parameters.
///           2. Deploys a new SherwoodToken (ERC-20) for the launch.
///           3. Clones the current LaunchProject implementation.
///           4. Initialises the clone via ILaunchProject.initialize().
///           5. Mints saleTokenAllocation tokens directly into the clone.
///           6. Writes an immutable LaunchInfo record to the registry.
///
///         Upgrade safety
///         ───────────────
///         Updating `launchProjectImplementation` only affects future launches.
///         All previously deployed clones continue pointing to their original
///         implementation, preserving historical behavior.
///
///         Spam protection
///         ────────────────
///         Each creator address is limited to MAX_LAUNCHES_PER_CREATOR concurrent
///         active launches. Because LaunchProject clones do not call back to the
///         factory on termination, this counter is decremented via a manual
///         `noteTerminated()` call by the operator after a launch reaches a
///         terminal state (Graduated or Cancelled).
///
///         Ownership
///         ──────────
///         Uses Ownable2Step — the nominee must accept before the transfer completes,
///         preventing accidental ownership loss.
contract SherwoodFactory is Ownable2Step, Pausable, SherwoodEvents {

    // ── State ─────────────────────────────────────────────────────────────────

    /// @notice Address that receives protocol fees on newly created launches.
    address public feeRecipient;

    /// @notice EIP-1167 implementation cloned by every createLaunch call.
    address public launchProjectImplementation;

    /// @notice Protocol fee in basis points applied to newly created launches.
    uint16 public protocolFeeBps;

    /// @dev Ordered list of every project address ever created by this factory.
    address[] private _projects;

    /// @dev Immutable launch configuration stored per project address.
    mapping(address project => LaunchTypes.LaunchInfo info) private _launches;

    /// @dev Number of active (non-terminal) launches per creator.
    ///      Incremented at createLaunch; decremented via noteTerminated().
    mapping(address creator => uint256 count) private _activeLaunchCount;

    // ── Constructor ───────────────────────────────────────────────────────────

    /// @notice Deploys the factory and validates all initial parameters.
    /// @param initialOwner                  Owner address (protocol multisig recommended).
    /// @param initialLaunchProjectImpl      Address of an already-deployed LaunchProject
    ///                                      implementation with deployed bytecode.
    /// @param initialFeeRecipient           Address that collects protocol fees.
    /// @param initialProtocolFeeBps         Initial fee in basis points (0–MAX_PROTOCOL_FEE_BPS).
    constructor(
        address initialOwner,
        address initialLaunchProjectImpl,
        address initialFeeRecipient,
        uint16 initialProtocolFeeBps
    ) Ownable(initialOwner) {
        if (initialOwner == address(0) || initialFeeRecipient == address(0)) {
            revert SherwoodErrors.InvalidAddress();
        }
        _setLaunchProjectImplementation(initialLaunchProjectImpl);
        _setProtocolFee(initialProtocolFeeBps);
        feeRecipient = initialFeeRecipient;
    }

    // ── External: launch creation ─────────────────────────────────────────────

    /// @notice Deploys a new SherwoodToken and a corresponding fixed-price LaunchProject clone.
    ///         Reverts if the factory is paused, if any parameter is invalid, or if the
    ///         caller has reached MAX_LAUNCHES_PER_CREATOR active launches.
    /// @param  params  Creator-supplied launch configuration.
    /// @return project Address of the newly deployed LaunchProject clone.
    /// @return token   Address of the newly deployed SherwoodToken.
    function createLaunch(LaunchTypes.CreateLaunchParams calldata params)
        external
        whenNotPaused
        returns (address project, address token)
    {
        _validateLaunchParameters(params);

        uint256 active = _activeLaunchCount[msg.sender];
        if (active >= LaunchConstants.MAX_LAUNCHES_PER_CREATOR) {
            revert SherwoodErrors.TooManyActiveLaunches(msg.sender, LaunchConstants.MAX_LAUNCHES_PER_CREATOR);
        }

        SherwoodToken launchToken = new SherwoodToken(
            params.tokenName, params.tokenSymbol, address(this), msg.sender
        );
        project = Clones.clone(launchProjectImplementation);
        token = address(launchToken);

        ILaunchProject(project).initialize(
            LaunchTypes.LaunchInit({
                factory: address(this),
                creator: msg.sender,
                token: token,
                feeRecipient: feeRecipient,
                protocolFeeBps: protocolFeeBps,
                saleTokenAllocation: params.saleTokenAllocation,
                tokenPrice: params.tokenPrice,
                softCap: params.softCap,
                maxRaise: params.maxRaise,
                startTime: params.startTime,
                endTime: params.endTime
            })
        );
        launchToken.mint(project, params.saleTokenAllocation);

        _launches[project] = LaunchTypes.LaunchInfo({
            creator: msg.sender,
            token: token,
            saleTokenAllocation: params.saleTokenAllocation,
            tokenPrice: params.tokenPrice,
            softCap: params.softCap,
            maxRaise: params.maxRaise,
            startTime: params.startTime,
            endTime: params.endTime,
            protocolFeeBps: protocolFeeBps
        });
        _projects.push(project);
        _activeLaunchCount[msg.sender] += 1;

        emit ProjectCreated(project, token, msg.sender);
    }

    // ── External: operator callbacks ─────────────────────────────────────────

    /// @notice Decrements the creator's active launch count once a launch reaches
    ///         a terminal state (Graduated or Cancelled).
    /// @dev    LaunchProject clones do not call back to this factory on termination,
    ///         so the operator must call this function manually after confirming the
    ///         launch state. Only callable by the owner.
    ///         Reverts if the launch is not registered or if the creator's count is
    ///         already zero.
    /// @param  project  Address of the LaunchProject clone to mark as terminated.
    function noteTerminated(address project) external onlyOwner {
        LaunchTypes.LaunchInfo storage info = _launches[project];
        if (info.creator == address(0)) revert SherwoodErrors.NotALaunch(project);

        address launchCreator = info.creator;
        if (_activeLaunchCount[launchCreator] > 0) {
            _activeLaunchCount[launchCreator] -= 1;
        }
    }

    // ── External: governance ─────────────────────────────────────────────────

    /// @notice Pauses new launch creation. All existing clones continue unaffected.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes new launch creation after a pause.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Updates the protocol fee applied to launches created after this call.
    ///         Previously created launches retain their original fee.
    /// @param  newProtocolFeeBps  New fee in basis points. Must not exceed MAX_PROTOCOL_FEE_BPS.
    function setProtocolFee(uint16 newProtocolFeeBps) external onlyOwner {
        _setProtocolFee(newProtocolFeeBps);
    }

    /// @notice Updates the fee recipient used by launches created after this call.
    ///         Previously created launches retain their original fee recipient.
    /// @param  newFeeRecipient  Non-zero recipient address.
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert SherwoodErrors.InvalidAddress();
        address previousRecipient = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(previousRecipient, newFeeRecipient);
    }

    /// @notice Replaces the LaunchProject implementation cloned by future createLaunch calls.
    ///         Previously deployed clones are unaffected.
    /// @param  newImplementation  Address of a deployed contract with bytecode.
    function setLaunchProjectImplementation(address newImplementation) external onlyOwner {
        _setLaunchProjectImplementation(newImplementation);
    }

    // ── External: views ───────────────────────────────────────────────────────

    /// @notice Returns the immutable launch configuration registered for a project.
    ///         Returns a zero-valued struct for unregistered addresses.
    /// @param  project  LaunchProject clone address.
    function getLaunch(address project) external view returns (LaunchTypes.LaunchInfo memory) {
        return _launches[project];
    }

    /// @notice Returns a project address by zero-based index.
    ///         Reverts with a standard array-bounds panic if index >= projectCount().
    /// @param  index  Zero-based position in the project registry.
    function projectAt(uint256 index) external view returns (address) {
        return _projects[index];
    }

    /// @notice Returns the total number of projects ever deployed by this factory.
    function projectCount() external view returns (uint256) {
        return _projects.length;
    }

    /// @notice Returns the number of active (non-terminal) launches for a creator.
    /// @param  creator  Creator address to query.
    function getActiveLaunchCount(address creator) external view returns (uint256) {
        return _activeLaunchCount[creator];
    }

    /// @notice Returns true if the given address was deployed and registered by this factory.
    /// @param  project  Address to check.
    function isRegistered(address project) external view returns (bool) {
        return _launches[project].creator != address(0);
    }

    // ── Private: setters ──────────────────────────────────────────────────────

    /// @dev Validates and stores a new protocol fee, emitting ProtocolFeeUpdated.
    function _setProtocolFee(uint16 newProtocolFeeBps) private {
        if (newProtocolFeeBps > LaunchConstants.MAX_PROTOCOL_FEE_BPS) {
            revert SherwoodErrors.InvalidFeeBps(newProtocolFeeBps);
        }
        uint16 previousFeeBps = protocolFeeBps;
        protocolFeeBps = newProtocolFeeBps;
        emit ProtocolFeeUpdated(previousFeeBps, newProtocolFeeBps);
    }

    /// @dev Validates and stores a new implementation address, emitting
    ///      LaunchProjectImplementationUpdated. Reverts if the address has no code.
    function _setLaunchProjectImplementation(address newImplementation) private {
        if (newImplementation == address(0) || newImplementation.code.length == 0) {
            revert SherwoodErrors.InvalidAddress();
        }
        address previousImplementation = launchProjectImplementation;
        launchProjectImplementation = newImplementation;
        emit LaunchProjectImplementationUpdated(previousImplementation, newImplementation);
    }

    /// @dev Validates all creator-supplied CreateLaunchParams.
    ///      Checks are ordered cheapest-first to fail as early as possible.
    ///      Enforces MIN_SALE_DURATION_SECONDS between startTime and endTime.
    function _validateLaunchParameters(LaunchTypes.CreateLaunchParams calldata params) private view {
        if (bytes(params.tokenName).length == 0 || bytes(params.tokenSymbol).length == 0) {
            revert SherwoodErrors.InvalidLaunchConfiguration();
        }
        if (
            params.saleTokenAllocation == 0 || params.tokenPrice == 0 || params.softCap == 0
                || params.maxRaise < params.softCap
        ) revert SherwoodErrors.InvalidLaunchConfiguration();
        if (params.startTime < block.timestamp) revert SherwoodErrors.InvalidLaunchConfiguration();
        if (
            params.endTime <= params.startTime
                || params.endTime - params.startTime < LaunchConstants.MIN_SALE_DURATION_SECONDS
        ) revert SherwoodErrors.InvalidLaunchDuration();
    }
}
