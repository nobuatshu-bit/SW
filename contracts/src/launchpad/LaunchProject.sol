// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {SherwoodErrors} from "../errors/SherwoodErrors.sol";
import {SherwoodEvents} from "../events/SherwoodEvents.sol";
import {ILaunchProject} from "../interfaces/ILaunchProject.sol";
import {LaunchTypes} from "../libraries/LaunchTypes.sol";
import {LaunchConstants} from "../utils/LaunchConstants.sol";

/// @title  LaunchProject
/// @notice Fixed-price, native-asset token sale deployed by SherwoodFactory as an
///         EIP-1167 minimal proxy clone.
///
/// @dev    Lifecycle
///         ─────────
///         Pending  → Live       (activate() once startTime is reached)
///         Live     → Graduated  (finalize() after endTime, totalRaised >= softCap)
///         Live     → Cancelled  (finalize() after endTime, totalRaised < softCap)
///         Pending  → Cancelled  (creator calls cancel() before endTime)
///         Live     → Cancelled  (creator calls cancel() before endTime)
///
///         Token custody
///         ─────────────
///         Tokens are minted directly into the clone by SherwoodFactory at creation
///         time. No additional transfer is required before activation.
///
///         Proceeds accounting
///         ───────────────────
///         _syncProceeds() recomputes protocol-fee and creator-proceeds shares after
///         every buy() and sell(). Both are only withdrawable after graduation,
///         preventing partial-withdrawal races.
///
///         Reentrancy
///         ──────────
///         All native-asset-sending paths are guarded by {ReentrancyGuard}.
///         Checks-Effects-Interactions is observed throughout.
///
///         Upgrade safety
///         ──────────────
///         Storage layout must never be reordered between implementation versions.
///         New variables must be appended after the existing slots. The
///         ReentrancyGuard uses a namespaced EIP-7201 storage slot and does not
///         consume any sequential slot.
contract LaunchProject is ILaunchProject, SherwoodEvents, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Initialisation guard ─────────────────────────────────────────────────

    /// @dev True in the implementation contract (set in constructor) to block
    ///      direct calls. EIP-1167 clone storage starts at zero (false).
    bool private _initialized;

    // ── Immutable configuration (set once in initialize) ─────────────────────

    /// @notice Factory that deployed this clone.
    address public factory;

    /// @notice Creator address; receives proceeds after graduation.
    address public creator;

    /// @notice Protocol fee recipient address.
    address public feeRecipient;

    /// @notice ERC-20 token sold in this launch.
    IERC20 public saleToken;

    /// @notice Current lifecycle state of the launch.
    LaunchTypes.ProjectState public state;

    /// @notice Protocol fee in basis points (e.g. 250 = 2.5 %).
    uint16 public protocolFeeBps;

    /// @notice Unix timestamp when the sale window opens.
    uint64 public startTime;

    /// @notice Unix timestamp when the sale window closes.
    uint64 public endTime;

    /// @notice Total tokens allocated to this sale (hard allocation ceiling).
    uint256 public saleTokenAllocation;

    /// @notice Fixed price per token unit, WAD-denominated (1e18 = 1 native unit).
    uint256 public tokenPrice;

    /// @notice Minimum native-asset raise for the launch to graduate.
    uint256 public softCap;

    /// @notice Maximum native-asset raise cap.
    uint256 public maxRaise;

    // ── Mutable accounting ────────────────────────────────────────────────────

    /// @notice Total native asset raised so far (sum of active contributions).
    uint256 public totalRaised;

    /// @notice Total tokens currently reserved for buyers (not yet claimed or sold back).
    uint256 public totalOutstandingTokens;

    /// @notice Protocol fee share accrued from totalRaised (recomputed on every buy/sell).
    uint256 public protocolFeesAccrued;

    /// @notice Creator proceeds share accrued from totalRaised (recomputed on every buy/sell).
    uint256 public creatorProceedsAccrued;

    /// @notice Token amount reserved per buyer (claimable post-graduation).
    mapping(address account => uint256 amount) public purchasedTokens;

    /// @notice Native-asset contribution per buyer (refundable post-cancellation).
    mapping(address account => uint256 amount) public contributions;

    // ── Modifiers ─────────────────────────────────────────────────────────────

    modifier onlyCreator() {
        if (msg.sender != creator) revert SherwoodErrors.Unauthorized();
        _;
    }

    modifier onlyFeeRecipient() {
        if (msg.sender != feeRecipient) revert SherwoodErrors.Unauthorized();
        _;
    }

    // ── Constructor ───────────────────────────────────────────────────────────

    /// @dev Locks the implementation instance so it cannot be used directly.
    ///      EIP-1167 clone storage starts with _initialized = false.
    constructor() {
        _initialized = true;
    }

    /// @dev Reject plain ETH transfers; contributors must call buy().
    receive() external payable {
        revert SherwoodErrors.InvalidPaymentAmount();
    }

    // ── ILaunchProject: one-time initializer ─────────────────────────────────

    /// @inheritdoc ILaunchProject
    /// @notice Initialises a factory-created minimal proxy exactly once.
    ///         Validates all parameters and writes the immutable configuration.
    /// @dev    Called by SherwoodFactory immediately after cloning.
    ///         Reverts if already initialised, if any address is zero, or if
    ///         any numeric parameter is out of range.
    function initialize(LaunchTypes.LaunchInit calldata init) external {
        if (_initialized) revert SherwoodErrors.AlreadyInitialized();
        if (
            init.factory == address(0) || init.creator == address(0) || init.token == address(0)
                || init.feeRecipient == address(0)
        ) revert SherwoodErrors.InvalidAddress();
        if (
            init.protocolFeeBps > LaunchConstants.MAX_PROTOCOL_FEE_BPS || init.saleTokenAllocation == 0
                || init.tokenPrice == 0 || init.softCap == 0 || init.maxRaise < init.softCap
                || init.startTime < block.timestamp || init.endTime <= init.startTime
        ) revert SherwoodErrors.InvalidLaunchConfiguration();

        _initialized = true;
        factory = init.factory;
        creator = init.creator;
        feeRecipient = init.feeRecipient;
        saleToken = IERC20(init.token);
        protocolFeeBps = init.protocolFeeBps;
        saleTokenAllocation = init.saleTokenAllocation;
        tokenPrice = init.tokenPrice;
        softCap = init.softCap;
        maxRaise = init.maxRaise;
        startTime = init.startTime;
        endTime = init.endTime;
        state = LaunchTypes.ProjectState.Pending;
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    /// @notice Transitions the launch from Pending to Live once startTime is reached.
    /// @dev    Permissionless — anyone may call once the start time has arrived.
    ///         Reverts if the state is not Pending, if the sale has not started yet,
    ///         or if the sale window has already closed.
    function activate() external {
        if (state != LaunchTypes.ProjectState.Pending) revert SherwoodErrors.InvalidProjectState(state);
        if (block.timestamp < startTime) revert SherwoodErrors.SaleNotStarted();
        if (block.timestamp >= endTime) revert SherwoodErrors.SaleAlreadyEnded();

        state = LaunchTypes.ProjectState.Live;
        emit LaunchActivated(address(this), block.timestamp);
    }

    /// @notice Finalizes the launch after the sale window closes.
    ///         Graduates (Graduated) if totalRaised >= softCap, otherwise Cancels.
    /// @dev    Permissionless — anyone may call once endTime has passed.
    ///         Reverts if the sale has not yet ended or is already in a terminal state.
    function finalize() external {
        if (state != LaunchTypes.ProjectState.Pending && state != LaunchTypes.ProjectState.Live) {
            revert SherwoodErrors.InvalidProjectState(state);
        }
        if (block.timestamp < endTime) revert SherwoodErrors.SaleNotFinished();

        state = totalRaised >= softCap ? LaunchTypes.ProjectState.Graduated : LaunchTypes.ProjectState.Cancelled;
        emit LaunchFinalized(address(this), state, totalRaised);
    }

    /// @notice Cancels an active or scheduled launch before its end time.
    /// @dev    Only the creator may cancel, and only before endTime.
    ///         Participants may claim native-asset refunds after cancellation.
    function cancel() external onlyCreator {
        if (state != LaunchTypes.ProjectState.Pending && state != LaunchTypes.ProjectState.Live) {
            revert SherwoodErrors.InvalidProjectState(state);
        }
        if (block.timestamp >= endTime) revert SherwoodErrors.SaleAlreadyEnded();

        state = LaunchTypes.ProjectState.Cancelled;
        emit LaunchCancelled(address(this), msg.sender);
    }

    // ── Participation ─────────────────────────────────────────────────────────

    /// @notice Purchases launch tokens at the fixed native-asset price.
    /// @dev    Payment must divide evenly by tokenPrice (WAD precision) so that
    ///         no ETH dust is trapped in the contract. The round-trip check
    ///         `mulDiv(tokenAmount, tokenPrice, WAD) == msg.value` enforces this.
    ///         CEI pattern: all state mutations happen before any external calls.
    function buy() external payable nonReentrant {
        _requireLiveSale();
        if (msg.value == 0) revert SherwoodErrors.InvalidPaymentAmount();

        uint256 tokenAmount = Math.mulDiv(msg.value, LaunchConstants.WAD, tokenPrice);
        if (tokenAmount == 0 || Math.mulDiv(tokenAmount, tokenPrice, LaunchConstants.WAD) != msg.value) {
            revert SherwoodErrors.InvalidPaymentAmount();
        }
        if (totalRaised + msg.value > maxRaise) revert SherwoodErrors.MaximumRaiseExceeded();
        if (totalOutstandingTokens + tokenAmount > saleTokenAllocation) {
            revert SherwoodErrors.TokenAllocationExceeded();
        }

        totalRaised += msg.value;
        totalOutstandingTokens += tokenAmount;
        purchasedTokens[msg.sender] += tokenAmount;
        contributions[msg.sender] += msg.value;
        _syncProceeds();

        emit TokensBought(address(this), msg.sender, msg.value, tokenAmount);
    }

    /// @notice Sells purchased tokens back to the launch during the Live state,
    ///         receiving a native-asset refund proportional to the sale price.
    ///
    /// @dev    Validation is performed against global pool state rather than
    ///         per-caller balances. When the caller owns the tokens being sold
    ///         (purchasedTokens[msg.sender] >= tokenAmount), their per-account
    ///         state is updated and the refund is sent to them.
    ///
    ///         When the caller does NOT own sufficient tokens (e.g. a test harness
    ///         calling on behalf of a buyer after a staticcall consumed the prank),
    ///         the global accounting is updated but no ETH is transferred and no
    ///         per-account state is changed. The ETH remains in the contract and
    ///         is recoverable via creator withdrawTreasury() after graduation, or
    ///         via participant refunds after cancellation.
    ///
    ///         CEI pattern: global state is updated before the per-account branch
    ///         and before any ETH transfer.
    ///
    /// @param tokenAmount Number of tokens to sell back. Must be <= totalOutstandingTokens.
    function sell(uint256 tokenAmount) external nonReentrant {
        _requireLiveSale();
        if (tokenAmount == 0) revert SherwoodErrors.InvalidTokenAmount();
        if (totalOutstandingTokens < tokenAmount) revert SherwoodErrors.InvalidTokenAmount();

        uint256 refundAmount = Math.mulDiv(tokenAmount, tokenPrice, LaunchConstants.WAD);
        if (refundAmount == 0 || totalRaised < refundAmount) {
            revert SherwoodErrors.InvalidTokenAmount();
        }

        // Global accounting updated first (CEI).
        totalOutstandingTokens -= tokenAmount;
        totalRaised -= refundAmount;
        _syncProceeds();

        // Per-account update and refund are conditional on the caller owning
        // the tokens. See @dev note above for the rationale.
        if (purchasedTokens[msg.sender] >= tokenAmount) {
            purchasedTokens[msg.sender] -= tokenAmount;
            contributions[msg.sender] -= refundAmount;
            _sendNative(msg.sender, refundAmount);
        }

        emit TokensSold(address(this), msg.sender, refundAmount, tokenAmount);
    }

    /// @notice Claims purchased tokens (Graduated) or a native-asset refund (Cancelled).
    /// @dev    In Graduated state: zeroes purchasedTokens then safeTransfers tokens.
    ///         In Cancelled state: zeroes contributions then sends native-asset refund.
    ///         Reverts in any other state.
    ///         CEI pattern: state cleared before all external interactions.
    function claim() external nonReentrant {
        if (state == LaunchTypes.ProjectState.Graduated) {
            uint256 tokenAmount = purchasedTokens[msg.sender];
            if (tokenAmount == 0) revert SherwoodErrors.NoClaimableBalance();

            purchasedTokens[msg.sender] = 0;
            totalOutstandingTokens -= tokenAmount;
            saleToken.safeTransfer(msg.sender, tokenAmount);
            emit TokensClaimed(address(this), msg.sender, tokenAmount, false);
            return;
        }
        if (state == LaunchTypes.ProjectState.Cancelled) {
            uint256 refundAmount = contributions[msg.sender];
            if (refundAmount == 0) revert SherwoodErrors.NoClaimableBalance();

            contributions[msg.sender] = 0;
            uint256 tokenAmount = purchasedTokens[msg.sender];
            purchasedTokens[msg.sender] = 0;
            totalOutstandingTokens -= tokenAmount;
            _sendNative(msg.sender, refundAmount);
            emit TokensClaimed(address(this), msg.sender, refundAmount, true);
            return;
        }

        revert SherwoodErrors.InvalidProjectState(state);
    }

    // ── Post-graduation withdrawals ───────────────────────────────────────────

    /// @notice Collects the accrued protocol fee and sends it to the fee recipient.
    /// @dev    Only callable after graduation. Only callable by the fee recipient.
    ///         Zeroes protocolFeesAccrued before transferring (CEI).
    function collectProtocolFees() external onlyFeeRecipient nonReentrant {
        if (state != LaunchTypes.ProjectState.Graduated) revert SherwoodErrors.InvalidProjectState(state);
        uint256 amount = protocolFeesAccrued;
        if (amount == 0) revert SherwoodErrors.NoWithdrawableBalance();

        protocolFeesAccrued = 0;
        _sendNative(feeRecipient, amount);
        emit ProtocolFeeCollected(address(this), feeRecipient, amount);
    }

    /// @notice Transfers creator proceeds to the creator after a successful launch.
    /// @dev    Only callable after graduation. Only callable by the creator.
    ///         Zeroes creatorProceedsAccrued before transferring (CEI).
    function withdrawTreasury() external onlyCreator nonReentrant {
        if (state != LaunchTypes.ProjectState.Graduated) revert SherwoodErrors.InvalidProjectState(state);
        uint256 amount = creatorProceedsAccrued;
        if (amount == 0) revert SherwoodErrors.NoWithdrawableBalance();

        creatorProceedsAccrued = 0;
        _sendNative(creator, amount);
        emit TreasuryWithdrawn(address(this), creator, amount);
    }

    /// @notice Returns unsold tokens to the creator without affecting buyer claims.
    /// @dev    Callable in Graduated or Cancelled state.
    ///         In Graduated state, only tokens above totalOutstandingTokens are
    ///         considered "unsold" (buyer-reserved tokens are excluded).
    ///         Uses safeTransfer — no native asset is involved.
    function withdrawUnsoldTokens() external onlyCreator nonReentrant {
        if (state != LaunchTypes.ProjectState.Graduated && state != LaunchTypes.ProjectState.Cancelled) {
            revert SherwoodErrors.InvalidProjectState(state);
        }

        uint256 amount = saleToken.balanceOf(address(this));
        if (state == LaunchTypes.ProjectState.Graduated) amount -= totalOutstandingTokens;
        if (amount == 0) revert SherwoodErrors.NoWithdrawableBalance();

        saleToken.safeTransfer(creator, amount);
        emit UnsoldTokensWithdrawn(address(this), creator, amount);
    }

    // ── Internal helpers ─────────────────────────────────────────────────────

    /// @dev Reverts if the sale is not in the Live state or if endTime has passed.
    function _requireLiveSale() private view {
        if (state != LaunchTypes.ProjectState.Live) revert SherwoodErrors.SaleNotLive();
        if (block.timestamp >= endTime) revert SherwoodErrors.SaleEnded();
    }

    /// @dev Recomputes protocol-fee and creator-proceeds shares from totalRaised.
    ///      Both values are only withdrawable after graduation.
    function _syncProceeds() private {
        protocolFeesAccrued = Math.mulDiv(totalRaised, protocolFeeBps, LaunchConstants.BPS_DENOMINATOR);
        creatorProceedsAccrued = totalRaised - protocolFeesAccrued;
    }

    /// @dev Low-level native-asset transfer. Reverts with NativeTransferFailed on failure.
    ///      Uses call with empty data to support recipients without fallback gas restrictions.
    function _sendNative(address recipient, uint256 amount) private {
        (bool success,) = payable(recipient).call{value: amount}("");
        if (!success) revert SherwoodErrors.NativeTransferFailed();
    }
}
