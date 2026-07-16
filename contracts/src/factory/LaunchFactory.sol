// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {SherwoodErrors} from "../errors/SherwoodErrors.sol";
import {ILaunch} from "../interfaces/ILaunch.sol";
import {ILaunchFactory} from "../interfaces/ILaunchFactory.sol";
import {LaunchConstants} from "../utils/LaunchConstants.sol";
import {LaunchTypes} from "../libraries/LaunchTypes.sol";

/// @title LaunchFactory
/// @author SHERWOOD Labs
/// @notice Deploys gas-efficient EIP-1167 Launch clones and maintains an on-chain
///         registry of every launch ever created.
///
/// @dev Architecture overview
///      ─────────────────────
///      LaunchFactory is the single entry point for creating a new SHERWOOD launch.
///      It is intentionally decoupled from the Launch contract: it depends only on
///      the minimal ILaunch interface, so the launch implementation can be upgraded
///      without changing this contract.
///
///      Ownership uses Ownable2Step, requiring the nominee to accept before the
///      transfer completes, preventing accidental key-loss.
///
///      Launch creation is pausable at the factory level without affecting the
///      lifecycle of existing launches.
///
///      Registry design
///      ───────────────
///      Three data structures are maintained:
///        1. _allLaunches[]       — ordered list of every launch address (global index)
///        2. _launchRecords[addr] — immutable LaunchRecord per launch
///        3. _creatorLaunches[]   — per-creator ordered list of launch addresses
///        4. _activeLaunchCount   — per-creator count of non-terminal launches
///
///      The active count is incremented at creation and decremented when a launch
///      transitions to Graduated or Cancelled via noteTerminal(). noteTerminal() is
///      callable by any registered launch clone (verified via _launchRecords).
contract LaunchFactory is ILaunchFactory, Ownable2Step, Pausable {

    // ── Events ────────────────────────────────────────────────────────────────

    /// @notice Emitted when a new Launch clone is deployed and registered.
    /// @param launch     Address of the deployed Launch clone.
    /// @param creator    Address of the creator who submitted the launch.
    /// @param token      ERC-20 token address for the sale.
    /// @param index      Zero-based position in the global launch registry.
    /// @param createdAt  Block timestamp of the creation transaction.
    event LaunchCreated(
        address indexed launch,
        address indexed creator,
        address indexed token,
        uint256 index,
        uint64  createdAt
    );

    /// @notice Emitted when the owner updates the protocol fee.
    /// @param previousFeeBps Old fee value in basis points.
    /// @param newFeeBps      New fee value in basis points.
    event ProtocolFeeUpdated(uint16 indexed previousFeeBps, uint16 indexed newFeeBps);

    /// @notice Emitted when the owner updates the fee recipient.
    /// @param previousRecipient Old fee recipient address.
    /// @param newRecipient      New fee recipient address.
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);

    /// @notice Emitted when the owner replaces the Launch implementation.
    /// @param previousImpl Old implementation address.
    /// @param newImpl      New implementation address.
    event LaunchImplementationUpdated(address indexed previousImpl, address indexed newImpl);

    /// @notice Emitted by noteTerminal() when a launch reaches a terminal state.
    /// @param launch  Address of the Launch clone.
    /// @param creator Creator of that launch.
    event LaunchTerminated(address indexed launch, address indexed creator);

    // ── State ─────────────────────────────────────────────────────────────────

    /// @notice Protocol fee in basis points applied to raised funds in new launches.
    uint16 public protocolFeeBps;

    /// @notice Address that collects protocol fees from graduated launches.
    address public feeRecipient;

    /// @notice EIP-1167 implementation cloned by every createLaunch call.
    address public launchImplementation;

    /// @dev Ordered list of every launch address ever created by this factory.
    address[] private _allLaunches;

    /// @dev Immutable record stored per launch address at creation time.
    mapping(address launch => LaunchTypes.LaunchRecord) private _launchRecords;

    /// @dev Ordered list of launch addresses per creator, newest last.
    mapping(address creator => address[]) private _creatorLaunches;

    /// @dev Count of non-terminal (not Graduated, not Cancelled) launches per creator.
    ///      Incremented at createLaunch; decremented at noteTerminal.
    mapping(address creator => uint256 count) private _activeLaunchCount;

    // ── Constructor ───────────────────────────────────────────────────────────

    /// @notice Deploys the factory and validates all initial parameters.
    /// @param initialOwner_          Owner address that controls factory governance.
    /// @param initialImplementation_ Address of an already-deployed Launch implementation.
    /// @param initialFeeRecipient_   Address that will collect protocol fees.
    /// @param initialProtocolFeeBps_ Initial fee in basis points (0–MAX_PROTOCOL_FEE_BPS).
    constructor(
        address initialOwner_,
        address initialImplementation_,
        address initialFeeRecipient_,
        uint16  initialProtocolFeeBps_
    ) Ownable(initialOwner_) {
        if (initialOwner_ == address(0) || initialFeeRecipient_ == address(0)) {
            revert SherwoodErrors.InvalidAddress();
        }
        _setLaunchImplementation(initialImplementation_);
        _setFeeRecipient(initialFeeRecipient_);
        _setProtocolFee(initialProtocolFeeBps_);
    }

    // ── External: launch creation ─────────────────────────────────────────────

    /// @inheritdoc ILaunchFactory
    /// @notice Deploys a new Launch clone, initialises it, and writes an immutable
    ///         LaunchRecord to the registry.
    ///
    /// @dev Validation sequence:
    ///        1. Factory-level pause check (whenNotPaused).
    ///        2. Parameter sanity via _validateParams().
    ///        3. Per-creator active launch cap via _activeLaunchCount.
    ///      If all checks pass the clone is deployed, initialised via ILaunch,
    ///      and recorded. The caller (creator) keeps custody of their token;
    ///      this factory does not custody any assets.
    function createLaunch(LaunchTypes.LaunchParams calldata params)
        external
        whenNotPaused
        returns (address launch)
    {
        _validateParams(params);

        uint256 activeLaunches = _activeLaunchCount[msg.sender];
        if (activeLaunches >= LaunchConstants.MAX_LAUNCHES_PER_CREATOR) {
            revert SherwoodErrors.TooManyActiveLaunches(msg.sender, LaunchConstants.MAX_LAUNCHES_PER_CREATOR);
        }

        // Deploy a minimal proxy pointing to the current implementation.
        // Gas cost: ~40k for the clone + ~20k for the STATICCALL to Clones.
        launch = Clones.clone(launchImplementation);

        // Initialise the clone. This is the only call the factory makes on the
        // launch contract. All subsequent interactions go directly to the launch.
        ILaunch(launch).initialize(
            address(this),
            msg.sender,
            params.token,
            feeRecipient,
            protocolFeeBps,
            params
        );

        // Build and store the immutable record.
        uint64 createdAt = uint64(block.timestamp);
        uint256 index = _allLaunches.length;

        _launchRecords[launch] = LaunchTypes.LaunchRecord({
            launch:         launch,
            creator:        msg.sender,
            token:          params.token,
            protocolFeeBps: protocolFeeBps,
            tokenPrice:     params.tokenPrice,
            tokenAllocation: params.tokenAllocation,
            softCap:        params.softCap,
            hardCap:        params.hardCap,
            startTime:      params.startTime,
            endTime:        params.endTime,
            createdAt:      createdAt
        });

        _allLaunches.push(launch);
        _creatorLaunches[msg.sender].push(launch);
        _activeLaunchCount[msg.sender] += 1;

        emit LaunchCreated(launch, msg.sender, params.token, index, createdAt);
    }

    // ── External: launch lifecycle callback ───────────────────────────────────

    /// @notice Called by a registered Launch clone when it reaches a terminal state
    ///         (Graduated or Cancelled) to decrement the creator's active launch count.
    /// @dev    Only callable by addresses that hold a LaunchRecord in this factory,
    ///         preventing arbitrary callers from manipulating creator limits.
    ///         The Launch contract (next sprint) will call this from finalize() and cancel().
    function noteTerminal() external {
        LaunchTypes.LaunchRecord storage record = _launchRecords[msg.sender];
        // A zero-address creator means msg.sender is not a registered launch.
        if (record.creator == address(0)) revert SherwoodErrors.Unauthorized();

        address creator = record.creator;
        if (_activeLaunchCount[creator] > 0) {
            _activeLaunchCount[creator] -= 1;
        }

        emit LaunchTerminated(msg.sender, creator);
    }

    // ── External: governance ──────────────────────────────────────────────────

    /// @inheritdoc ILaunchFactory
    /// @notice Pauses new launch creation. All existing Launch clones continue unaffected.
    function pause() external onlyOwner {
        _pause();
    }

    /// @inheritdoc ILaunchFactory
    /// @notice Resumes new launch creation after a pause.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc ILaunchFactory
    /// @notice Updates the protocol fee charged to launches created after this call.
    ///         Previously created launches are unaffected.
    function setProtocolFee(uint16 newFeeBps) external onlyOwner {
        _setProtocolFee(newFeeBps);
    }

    /// @inheritdoc ILaunchFactory
    /// @notice Updates the address that collects protocol fees on launches created
    ///         after this call. Previously created launches retain their fee recipient.
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        _setFeeRecipient(newFeeRecipient);
    }

    /// @inheritdoc ILaunchFactory
    /// @notice Replaces the Launch implementation cloned by future createLaunch calls.
    ///         Previously created launches continue pointing to their original implementation,
    ///         preserving historical behaviour.
    function setLaunchImplementation(address newImplementation) external onlyOwner {
        _setLaunchImplementation(newImplementation);
    }

    // ── External: views ───────────────────────────────────────────────────────

    /// @inheritdoc ILaunchFactory
    function launchCount() external view returns (uint256) {
        return _allLaunches.length;
    }

    /// @inheritdoc ILaunchFactory
    /// @dev Reverts with a standard array-bounds panic if index >= launchCount().
    function launchAt(uint256 index) external view returns (address) {
        return _allLaunches[index];
    }

    /// @inheritdoc ILaunchFactory
    /// @dev Returns a zero-valued struct for unregistered addresses (all fields zero).
    ///      Callers should check record.creator != address(0) to detect unregistered addresses.
    function getLaunchRecord(address launch)
        external
        view
        returns (LaunchTypes.LaunchRecord memory)
    {
        return _launchRecords[launch];
    }

    /// @inheritdoc ILaunchFactory
    /// @dev Returns a copy of the creator's launch array. For large arrays the caller
    ///      should use launchCount() + launchAt() with off-chain pagination instead.
    function getLaunchesByCreator(address creator)
        external
        view
        returns (address[] memory)
    {
        return _creatorLaunches[creator];
    }

    /// @inheritdoc ILaunchFactory
    function getActiveLaunchCount(address creator) external view returns (uint256) {
        return _activeLaunchCount[creator];
    }

    /// @notice Returns true if launch_ was deployed and registered by this factory.
    /// @param launch_ Address to check.
    function isRegistered(address launch_) external view returns (bool) {
        return _launchRecords[launch_].creator != address(0);
    }

    // ── Private: setters ─────────────────────────────────────────────────────

    function _setProtocolFee(uint16 newFeeBps) private {
        if (newFeeBps > LaunchConstants.MAX_PROTOCOL_FEE_BPS) {
            revert SherwoodErrors.InvalidFeeBps(newFeeBps);
        }
        uint16 previous = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(previous, newFeeBps);
    }

    function _setFeeRecipient(address newRecipient) private {
        if (newRecipient == address(0)) revert SherwoodErrors.InvalidAddress();
        address previous = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(previous, newRecipient);
    }

    function _setLaunchImplementation(address newImpl) private {
        if (newImpl == address(0) || newImpl.code.length == 0) {
            revert SherwoodErrors.InvalidAddress();
        }
        address previous = launchImplementation;
        launchImplementation = newImpl;
        emit LaunchImplementationUpdated(previous, newImpl);
    }

    // ── Private: validation ───────────────────────────────────────────────────

    /// @dev Validates all creator-supplied LaunchParams.
    ///      Checks are ordered cheapest-first to fail as early as possible.
    function _validateParams(LaunchTypes.LaunchParams calldata p) private view {
        // Address checks
        if (p.token == address(0)) revert SherwoodErrors.InvalidAddress();

        // String checks — names must be non-empty
        if (bytes(p.name).length == 0) revert SherwoodErrors.InvalidLaunchConfiguration();

        // Numeric checks
        if (p.tokenPrice == 0 || p.tokenAllocation == 0) {
            revert SherwoodErrors.InvalidTokenAmount();
        }
        if (p.softCap == 0 || p.hardCap < p.softCap) {
            revert SherwoodErrors.InvalidLaunchConfiguration();
        }
        // maxContribution = 0 means disabled; if set it must be >= minContribution
        if (p.maxContribution > 0 && p.maxContribution < p.minContribution) {
            revert SherwoodErrors.InvalidLaunchConfiguration();
        }

        // Schedule checks
        if (p.startTime < uint64(block.timestamp)) {
            revert SherwoodErrors.SaleNotStarted();
        }
        if (p.endTime <= p.startTime) {
            revert SherwoodErrors.InvalidLaunchDuration();
        }
    }
}
