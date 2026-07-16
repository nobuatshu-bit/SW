// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20}          from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20}       from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable}         from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step}    from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable}        from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math}            from "@openzeppelin/contracts/utils/math/Math.sol";

import {SherwoodErrors}  from "../errors/SherwoodErrors.sol";
import {LaunchConstants} from "../utils/LaunchConstants.sol";
import {LaunchTypes}     from "../libraries/LaunchTypes.sol";

/// @title Vesting
/// @author SHERWOOD Labs
/// @notice Linear token vesting with per-beneficiary cliff support, owner-controlled
///         revocation, and emergency pause.
///
/// @dev Architecture
///      ─────────────
///      One contract instance manages vesting for a single ERC-20 token.
///      The owner (typically a project multisig) creates schedules and transfers
///      the corresponding token amount to this contract at schedule creation time.
///
///      Vesting formula (per beneficiary, after cliff):
///        vested = totalAmount * min(elapsed, vestingDuration) / vestingDuration
///        claimable = vested - claimed
///
///      Before the cliff elapses, claimable == 0.
///
///      Revocation
///      ──────────
///      The owner may revoke any schedule. Revocation:
///        1. Marks the schedule as revoked.
///        2. Returns the unvested portion to the owner.
///        3. Leaves the already-vested (but unclaimed) tokens claimable by
///           the beneficiary indefinitely.
///
///      This ensures beneficiaries always receive tokens they have already earned.
///
///      Multiple schedules
///      ───────────────────
///      Each beneficiary may hold exactly one schedule. Re-vesting the same
///      beneficiary requires revoking the existing schedule first.
contract Vesting is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Events ────────────────────────────────────────────────────────────────

    /// @notice Emitted when a new vesting schedule is created.
    event ScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint64  startTime,
        uint64  cliffDuration,
        uint64  vestingDuration
    );

    /// @notice Emitted when a beneficiary claims vested tokens.
    event TokensClaimed(
        address indexed beneficiary,
        uint256 amount,
        uint256 totalClaimed
    );

    /// @notice Emitted when the owner revokes a schedule.
    event ScheduleRevoked(
        address indexed beneficiary,
        uint256 unvestedReturned
    );

    // ── State ─────────────────────────────────────────────────────────────────

    /// @notice The ERC-20 token distributed by this vesting contract.
    IERC20 public immutable token;

    /// @dev Per-beneficiary vesting schedule.
    mapping(address => LaunchTypes.VestingSchedule) private _schedules;

    /// @dev Set of all beneficiaries that have ever had a schedule. Used for enumeration.
    address[] private _beneficiaries;

    // ── Constructor ───────────────────────────────────────────────────────────

    /// @notice Deploys the vesting contract for a given token.
    /// @param token_       ERC-20 token to be vested.
    /// @param initialOwner Owner address (project multisig or deployer).
    constructor(address token_, address initialOwner) Ownable(initialOwner) {
        if (token_ == address(0) || initialOwner == address(0)) {
            revert SherwoodErrors.InvalidAddress();
        }
        token = IERC20(token_);
    }

    // ── Owner: schedule management ────────────────────────────────────────────

    /// @notice Creates a new linear vesting schedule for `beneficiary`.
    ///         Transfers `totalAmount` tokens from the owner to this contract.
    ///         Reverts if the beneficiary already has an active schedule.
    ///
    /// @param beneficiary     Address that will receive vested tokens.
    /// @param totalAmount     Total tokens to vest. Must be > 0.
    /// @param startTime_      Unix timestamp when vesting begins.
    /// @param cliffDuration_  Seconds until the first tokens become claimable.
    ///                        May be zero (no cliff).
    /// @param vestingDuration_ Total vesting period in seconds. Must be > cliffDuration_.
    function createSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint64  startTime_,
        uint64  cliffDuration_,
        uint64  vestingDuration_
    ) external onlyOwner {
        if (beneficiary == address(0)) revert SherwoodErrors.InvalidAddress();
        if (totalAmount == 0) revert SherwoodErrors.InvalidTokenAmount();
        if (vestingDuration_ == 0 || vestingDuration_ <= cliffDuration_) {
            revert SherwoodErrors.InvalidDuration();
        }
        if (vestingDuration_ > LaunchConstants.MAX_VESTING_DURATION) {
            revert SherwoodErrors.InvalidDuration();
        }
        if (startTime_ < uint64(block.timestamp)) {
            revert SherwoodErrors.SaleNotStarted();
        }

        LaunchTypes.VestingSchedule storage existing = _schedules[beneficiary];
        // Reject if an active (non-revoked, non-fully-claimed) schedule exists
        if (existing.totalAmount > 0 && !existing.revoked && existing.claimed < existing.totalAmount) {
            revert SherwoodErrors.ScheduleAlreadyExists(beneficiary);
        }

        // Capture whether this beneficiary is brand-new BEFORE overwriting storage.
        // After the write, existing.totalAmount will be non-zero, so we can't use it
        // to detect first-time registration.
        bool isNewBeneficiary = (existing.totalAmount == 0);

        _schedules[beneficiary] = LaunchTypes.VestingSchedule({
            totalAmount:     totalAmount,
            claimed:         0,
            startTime:       startTime_,
            cliffDuration:   cliffDuration_,
            vestingDuration: vestingDuration_,
            revoked:         false
        });

        // Only push to the enumeration array for first-time beneficiaries.
        // Re-scheduled beneficiaries (previously revoked) are already in the
        // array from their original schedule — pushing again would create a
        // duplicate entry that corrupts beneficiaryCount() and beneficiaryAt().
        if (isNewBeneficiary) {
            _beneficiaries.push(beneficiary);
        }

        // Pull tokens from owner. Owner must have approved this contract.
        token.safeTransferFrom(msg.sender, address(this), totalAmount);

        emit ScheduleCreated(beneficiary, totalAmount, startTime_, cliffDuration_, vestingDuration_);
    }

    /// @notice Revokes `beneficiary`'s schedule.
    ///         The unvested portion is transferred back to the owner.
    ///         Already-vested but unclaimed tokens remain claimable.
    ///
    /// @param beneficiary Address whose schedule to revoke.
    function revoke(address beneficiary) external onlyOwner nonReentrant {
        LaunchTypes.VestingSchedule storage schedule = _schedules[beneficiary];
        if (schedule.totalAmount == 0) revert SherwoodErrors.ScheduleNotFound(beneficiary);
        if (schedule.revoked)         revert SherwoodErrors.ScheduleRevoked(beneficiary);

        uint256 vested    = _vestedAmount(schedule);
        uint256 claimable = vested - schedule.claimed;
        uint256 unvested  = schedule.totalAmount - vested;

        // Mark revoked before transfer (CEI)
        schedule.revoked = true;

        // Return unvested tokens to owner
        if (unvested > 0) {
            token.safeTransfer(owner(), unvested);
        }

        emit ScheduleRevoked(beneficiary, unvested);

        // Note: claimable (vested but unclaimed) stays in the contract for the
        // beneficiary to collect. The beneficiary's claim() will still work.
        (claimable); // suppress unused warning — intentionally kept in contract
    }

    // ── Beneficiary: claim ────────────────────────────────────────────────────

    /// @notice Claim all currently vested and unclaimed tokens.
    ///         Callable only by the beneficiary themselves.
    function claim() external whenNotPaused nonReentrant {
        LaunchTypes.VestingSchedule storage schedule = _schedules[msg.sender];
        if (schedule.totalAmount == 0) revert SherwoodErrors.ScheduleNotFound(msg.sender);

        uint256 claimable = _claimableAmount(schedule);
        if (claimable == 0) revert SherwoodErrors.NoVestedTokens();

        // Effects before transfer (CEI)
        schedule.claimed += claimable;

        token.safeTransfer(msg.sender, claimable);
        emit TokensClaimed(msg.sender, claimable, schedule.claimed);
    }

    // ── Owner: emergency pause ────────────────────────────────────────────────

    /// @notice Pause claim(). Does not affect revoke() or owner withdrawals.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resume claim() after a pause.
    function unpause() external onlyOwner {
        _unpause();
    }

    // ── Views ─────────────────────────────────────────────────────────────────

    /// @notice Returns the full vesting schedule for a beneficiary.
    ///         Returns a zero-valued struct if no schedule exists.
    /// @param  beneficiary  Address whose schedule to look up.
    /// @return              The VestingSchedule struct stored for that address.
    function getSchedule(address beneficiary)
        external
        view
        returns (LaunchTypes.VestingSchedule memory)
    {
        return _schedules[beneficiary];
    }

    /// @notice Returns the total amount vested so far for a beneficiary (including
    ///         already-claimed tokens). Returns 0 if no schedule exists.
    /// @param  beneficiary  Address to query.
    /// @return              Cumulative vested amount in token wei.
    function vestedAmount(address beneficiary) external view returns (uint256) {
        return _vestedAmount(_schedules[beneficiary]);
    }

    /// @notice Returns the amount the beneficiary can claim right now.
    ///         Returns 0 if no schedule exists, before the cliff, or if all
    ///         vested tokens have already been claimed.
    /// @param  beneficiary  Address to query.
    /// @return              Claimable amount in token wei.
    function claimableAmount(address beneficiary) external view returns (uint256) {
        return _claimableAmount(_schedules[beneficiary]);
    }

    /// @notice Returns the total number of beneficiary addresses ever registered.
    /// @return  Count of unique beneficiary addresses in the enumeration array.
    function beneficiaryCount() external view returns (uint256) {
        return _beneficiaries.length;
    }

    /// @notice Returns a beneficiary address by zero-based index.
    ///         Reverts with a standard array-bounds panic if index >= beneficiaryCount().
    /// @param  index  Zero-based position in the beneficiary enumeration array.
    /// @return        Beneficiary address at that index.
    function beneficiaryAt(uint256 index) external view returns (address) {
        return _beneficiaries[index];
    }

    // ── Internal ─────────────────────────────────────────────────────────────

    /// @dev Computes the cumulative vested amount at the current block timestamp.
    ///      Returns 0 before the cliff elapses.
    ///      Returns totalAmount once the full vestingDuration has elapsed.
    ///      On a revoked schedule, returns only up to the point of revocation
    ///      (revocation is recorded by setting revoked=true; the vested formula
    ///       still computes correctly against the current timestamp, but the
    ///       unvested portion has already been returned to the owner).
    function _vestedAmount(LaunchTypes.VestingSchedule memory s)
        internal
        view
        returns (uint256)
    {
        if (s.totalAmount == 0) return 0;
        if (block.timestamp < uint256(s.startTime) + uint256(s.cliffDuration)) return 0;

        uint256 elapsed = block.timestamp - s.startTime;
        if (elapsed >= s.vestingDuration) return s.totalAmount;

        return Math.mulDiv(s.totalAmount, elapsed, s.vestingDuration);
    }

    /// @dev Returns the amount claimable right now (vested minus already claimed).
    ///      On a revoked schedule, caps at (vested at revocation - claimed) —
    ///      because the unvested portion was already returned, the remaining
    ///      contract balance equals exactly vested - claimed.
    function _claimableAmount(LaunchTypes.VestingSchedule memory s)
        internal
        view
        returns (uint256)
    {
        if (s.totalAmount == 0) return 0;
        uint256 vested = _vestedAmount(s);
        return vested > s.claimed ? vested - s.claimed : 0;
    }
}
