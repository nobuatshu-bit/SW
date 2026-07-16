// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20}        from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20}     from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math}          from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable}       from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable}      from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ILaunch}         from "../interfaces/ILaunch.sol";
import {ILaunchFactory}  from "../interfaces/ILaunchFactory.sol";
import {SherwoodErrors}  from "../errors/SherwoodErrors.sol";
import {LaunchConstants} from "../utils/LaunchConstants.sol";
import {LaunchTypes}     from "../libraries/LaunchTypes.sol";

/// @title Launch
/// @author SHERWOOD Labs
/// @notice Fixed-price ERC-20 token sale deployed by LaunchFactory as an EIP-1167 clone.
///
/// @dev Lifecycle
///      ──────────
///      Pending  → Active     (anyone calls activate() once startTime is reached)
///      Active   → Graduated  (finalize() called after endTime, totalRaised >= softCap)
///      Active   → Failed     (finalize() called after endTime, totalRaised < softCap)
///      Pending  → Failed     (creator calls cancel() before startTime)
///      Active   → Failed     (creator calls cancel() before endTime)
///
///      Token custody
///      ─────────────
///      The creator must transfer tokenAllocation tokens to this contract before
///      activating. This is enforced by activate(), which reads the contract's
///      ERC-20 balance. The factory does NOT custody tokens.
///
///      Proceeds accounting
///      ───────────────────
///      On every buy(), _syncProceeds() recomputes the protocol fee and creator
///      share from the current totalRaised. Both are withdrawable only after
///      graduation. This avoids any partial-withdrawal race condition.
///
///      Reentrancy
///      ──────────
///      All ETH-sending paths (buy refund via WETH-less revert check, refund,
///      withdrawTreasury, collectFees) are guarded by ReentrancyGuard. The
///      Checks-Effects-Interactions pattern is strictly followed throughout.
contract Launch is ILaunch, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Events ────────────────────────────────────────────────────────────────

    /// @notice Emitted when the sale transitions from Pending to Active.
    event SaleActivated(address indexed launch, uint64 activatedAt);

    /// @notice Emitted when a participant buys tokens.
    /// @param buyer         Participant address.
    /// @param nativeAmount  ETH contributed.
    /// @param tokenAmount   Tokens reserved for the buyer.
    event TokensPurchased(
        address indexed launch,
        address indexed buyer,
        uint256 nativeAmount,
        uint256 tokenAmount
    );

    /// @notice Emitted when a participant redeems tokens after graduation.
    event TokensClaimed(
        address indexed launch,
        address indexed claimant,
        uint256 tokenAmount
    );

    /// @notice Emitted when a participant is refunded after a failed sale.
    event ContributionRefunded(
        address indexed launch,
        address indexed participant,
        uint256 nativeAmount
    );

    /// @notice Emitted when the sale is finalised (Graduated or Failed).
    event SaleFinalized(
        address indexed launch,
        LaunchTypes.SaleState indexed state,
        uint256 totalRaised
    );

    /// @notice Emitted when the creator cancels the sale before endTime.
    event SaleCancelled(address indexed launch, address indexed cancelledBy);

    /// @notice Emitted when the creator withdraws proceeds after graduation.
    event TreasuryWithdrawn(address indexed launch, address indexed creator, uint256 amount);

    /// @notice Emitted when the protocol fee is collected after graduation.
    event ProtocolFeeCollected(address indexed launch, address indexed recipient, uint256 amount);

    /// @notice Emitted when the creator recovers unsold tokens.
    event UnsoldTokensWithdrawn(address indexed launch, address indexed creator, uint256 amount);

    // ── Immutables (set once in initialize) ───────────────────────────────────

    address public factory;
    address public creator;
    address public feeRecipient;
    IERC20  public saleToken;

    uint16  public protocolFeeBps;
    uint256 public tokenPrice;
    uint256 public tokenAllocation;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public minContribution;
    uint256 public maxContribution;
    uint64  public startTime;
    uint64  public endTime;

    // ── Mutable state ─────────────────────────────────────────────────────────

    LaunchTypes.SaleState public state;
    uint256 public totalRaised;
    uint256 public totalTokensReserved;
    uint256 public protocolFeesAccrued;
    uint256 public creatorProceedsAccrued;

    /// @notice Native-currency contribution per participant.
    mapping(address => uint256) public contributions;

    /// @notice Token amount reserved for each participant (claimable post-graduation).
    mapping(address => uint256) public purchasedTokens;

    // ── Initialisation guard ─────────────────────────────────────────────────

    /// @dev Set to true in the implementation constructor to block direct calls.
    ///      Clones start with this as false.
    bool private _initialized;

    // ── Modifiers ─────────────────────────────────────────────────────────────

    modifier onlyCreator() {
        if (msg.sender != creator) revert SherwoodErrors.Unauthorized();
        _;
    }

    modifier onlyFeeRecipient() {
        if (msg.sender != feeRecipient) revert SherwoodErrors.Unauthorized();
        _;
    }

    modifier onlyActive() {
        if (state != LaunchTypes.SaleState.Active) revert SherwoodErrors.SaleNotActive();
        if (block.timestamp >= endTime) revert SherwoodErrors.SaleEnded();
        _;
    }

    // ── Constructor ───────────────────────────────────────────────────────────

    /// @dev Locks the implementation so it cannot be used directly.
    ///      EIP-1167 clone storage starts with _initialized = false.
    constructor() Ownable(msg.sender) {
        _initialized = true;
    }

    /// @dev Reject plain ETH transfers; contributors must call buy().
    receive() external payable {
        revert SherwoodErrors.InvalidPaymentAmount();
    }

    // ── ILaunch: one-time initializer ─────────────────────────────────────────

    /// @inheritdoc ILaunch
    /// @notice Called exactly once by LaunchFactory immediately after cloning.
    ///         Validates all parameters, sets all immutable configuration, and
    ///         transfers ownership to the creator.
    function initialize(
        address factory_,
        address creator_,
        address token_,
        address feeRecipient_,
        uint16  protocolFeeBps_,
        LaunchTypes.LaunchParams calldata params
    ) external override {
        if (_initialized) revert SherwoodErrors.AlreadyInitialized();
        if (
            factory_      == address(0) ||
            creator_      == address(0) ||
            token_        == address(0) ||
            feeRecipient_ == address(0)
        ) revert SherwoodErrors.InvalidAddress();
        if (protocolFeeBps_ > LaunchConstants.MAX_PROTOCOL_FEE_BPS) {
            revert SherwoodErrors.InvalidFeeBps(protocolFeeBps_);
        }
        if (params.tokenPrice == 0 || params.tokenAllocation == 0) {
            revert SherwoodErrors.InvalidTokenAmount();
        }
        if (params.softCap == 0 || params.hardCap < params.softCap) {
            revert SherwoodErrors.InvalidLaunchConfiguration();
        }
        if (params.maxContribution > 0 && params.maxContribution < params.minContribution) {
            revert SherwoodErrors.InvalidLaunchConfiguration();
        }
        if (params.startTime < uint64(block.timestamp) || params.endTime <= params.startTime) {
            revert SherwoodErrors.InvalidLaunchConfiguration();
        }

        _initialized    = true;
        factory         = factory_;
        creator         = creator_;
        feeRecipient    = feeRecipient_;
        saleToken       = IERC20(token_);
        protocolFeeBps  = protocolFeeBps_;
        tokenPrice      = params.tokenPrice;
        tokenAllocation = params.tokenAllocation;
        softCap         = params.softCap;
        hardCap         = params.hardCap;
        minContribution = params.minContribution;
        maxContribution = params.maxContribution;
        startTime       = params.startTime;
        endTime         = params.endTime;
        state           = LaunchTypes.SaleState.Pending;

        // Transfer ownership to creator so they can pause/cancel
        _transferOwnership(creator_);
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    /// @notice Transitions the sale from Pending to Active once startTime is reached
    ///         AND the contract holds at least tokenAllocation tokens.
    /// @dev Permissionless — anyone can call once both conditions are met.
    ///      The token balance check ensures the creator has funded the contract.
    function activate() external {
        if (state != LaunchTypes.SaleState.Pending) {
            revert SherwoodErrors.SaleNotActive();
        }
        if (block.timestamp < startTime) revert SherwoodErrors.SaleNotStarted();
        if (block.timestamp >= endTime)  revert SherwoodErrors.SaleAlreadyEnded();
        if (saleToken.balanceOf(address(this)) < tokenAllocation) {
            revert SherwoodErrors.TokenAllocationExceeded();
        }

        state = LaunchTypes.SaleState.Active;
        emit SaleActivated(address(this), uint64(block.timestamp));
    }

    /// @notice Cancels the sale and moves it to Failed state.
    ///         Only the creator may cancel; only before endTime.
    function cancel() external onlyCreator {
        if (
            state != LaunchTypes.SaleState.Pending &&
            state != LaunchTypes.SaleState.Active
        ) revert SherwoodErrors.SaleNotActive();
        if (block.timestamp >= endTime) revert SherwoodErrors.SaleAlreadyEnded();

        state = LaunchTypes.SaleState.Failed;
        _noteTerminal();

        emit SaleCancelled(address(this), msg.sender);
    }

    /// @notice Finalises the sale after endTime.
    ///         Graduates if totalRaised >= softCap, otherwise marks as Failed.
    ///         Permissionless — anyone can call once the sale window has closed.
    function finalize() external {
        if (
            state != LaunchTypes.SaleState.Pending &&
            state != LaunchTypes.SaleState.Active
        ) revert SherwoodErrors.SaleNotActive();
        if (block.timestamp < endTime) revert SherwoodErrors.SaleNotFinished();

        if (totalRaised >= softCap) {
            state = LaunchTypes.SaleState.Graduated;
        } else {
            state = LaunchTypes.SaleState.Failed;
        }
        _noteTerminal();

        emit SaleFinalized(address(this), state, totalRaised);
    }

    // ── Participation ─────────────────────────────────────────────────────────

    /// @notice Purchase tokens at the fixed price.
    ///         Caller sends ETH; the proportional token amount is reserved.
    /// @dev Payment must divide evenly by tokenPrice (WAD-denominated) to prevent
    ///      dust ETH being trapped in the contract.
    ///      All accounting changes happen before any external calls (CEI pattern).
    function buy() external payable whenNotPaused nonReentrant onlyActive {
        if (msg.value == 0) revert SherwoodErrors.InvalidPaymentAmount();

        // Min contribution check
        if (minContribution > 0 && msg.value < minContribution) {
            revert SherwoodErrors.BelowMinContribution(msg.value, minContribution);
        }

        // Max contribution check (per-participant cumulative)
        uint256 newContribution = contributions[msg.sender] + msg.value;
        if (maxContribution > 0 && newContribution > maxContribution) {
            revert SherwoodErrors.MaxContributionExceeded(newContribution, maxContribution);
        }

        // Derive token amount from exact ETH payment (WAD precision)
        uint256 tokenAmt = Math.mulDiv(msg.value, LaunchConstants.WAD, tokenPrice);
        if (tokenAmt == 0) revert SherwoodErrors.InvalidPaymentAmount();
        // Round-trip check: ensure no ETH dust is trapped
        if (Math.mulDiv(tokenAmt, tokenPrice, LaunchConstants.WAD) != msg.value) {
            revert SherwoodErrors.InvalidPaymentAmount();
        }

        // Hard-cap and allocation checks
        if (totalRaised + msg.value > hardCap) revert SherwoodErrors.MaximumRaiseExceeded();
        if (totalTokensReserved + tokenAmt > tokenAllocation) {
            revert SherwoodErrors.TokenAllocationExceeded();
        }

        // Effects
        totalRaised           += msg.value;
        totalTokensReserved   += tokenAmt;
        contributions[msg.sender]    = newContribution;
        purchasedTokens[msg.sender] += tokenAmt;
        _syncProceeds();

        emit TokensPurchased(address(this), msg.sender, msg.value, tokenAmt);
    }

    /// @notice Claim reserved tokens after the sale graduates.
    ///         Transfers the full purchased amount to the caller and zeroes their balance.
    function claim() external whenNotPaused nonReentrant {
        if (state != LaunchTypes.SaleState.Graduated) {
            revert SherwoodErrors.SaleNotActive();
        }

        uint256 tokenAmt = purchasedTokens[msg.sender];
        if (tokenAmt == 0) revert SherwoodErrors.NoClaimableBalance();

        // Effects before transfer (CEI)
        purchasedTokens[msg.sender]  = 0;
        totalTokensReserved         -= tokenAmt;

        saleToken.safeTransfer(msg.sender, tokenAmt);
        emit TokensClaimed(address(this), msg.sender, tokenAmt);
    }

    /// @notice Refund the full contribution after a failed sale.
    ///         Sets the caller's contribution to zero before sending ETH (CEI).
    function refund() external nonReentrant {
        if (state != LaunchTypes.SaleState.Failed) {
            revert SherwoodErrors.SaleNotActive();
        }

        uint256 amount = contributions[msg.sender];
        if (amount == 0) revert SherwoodErrors.NoClaimableBalance();

        // Effects before interaction
        contributions[msg.sender]    = 0;
        purchasedTokens[msg.sender]  = 0;

        _sendNative(msg.sender, amount);
        emit ContributionRefunded(address(this), msg.sender, amount);
    }

    // ── Creator withdrawals ───────────────────────────────────────────────────

    /// @notice Withdraw creator proceeds after graduation.
    ///         Zeroes creatorProceedsAccrued before transferring (CEI).
    function withdrawTreasury() external onlyCreator nonReentrant {
        if (state != LaunchTypes.SaleState.Graduated) {
            revert SherwoodErrors.SaleNotActive();
        }

        uint256 amount = creatorProceedsAccrued;
        if (amount == 0) revert SherwoodErrors.NoWithdrawableBalance();

        creatorProceedsAccrued = 0;
        _sendNative(creator, amount);
        emit TreasuryWithdrawn(address(this), creator, amount);
    }

    /// @notice Recover unsold tokens after the sale ends (Graduated or Failed).
    ///         In Graduated state only the surplus above totalTokensReserved is returnable.
    function withdrawUnsoldTokens() external onlyCreator nonReentrant {
        if (
            state != LaunchTypes.SaleState.Graduated &&
            state != LaunchTypes.SaleState.Failed
        ) revert SherwoodErrors.SaleNotActive();

        uint256 balance = saleToken.balanceOf(address(this));
        uint256 reserved = (state == LaunchTypes.SaleState.Graduated)
            ? totalTokensReserved
            : 0;
        uint256 withdrawable = balance > reserved ? balance - reserved : 0;
        if (withdrawable == 0) revert SherwoodErrors.NoWithdrawableBalance();

        saleToken.safeTransfer(creator, withdrawable);
        emit UnsoldTokensWithdrawn(address(this), creator, withdrawable);
    }

    // ── Protocol fee collection ───────────────────────────────────────────────

    /// @notice Transfer the accrued protocol fee to the fee recipient.
    ///         Only callable after graduation. Only callable by the fee recipient.
    function collectProtocolFees() external onlyFeeRecipient nonReentrant {
        if (state != LaunchTypes.SaleState.Graduated) {
            revert SherwoodErrors.SaleNotActive();
        }

        uint256 amount = protocolFeesAccrued;
        if (amount == 0) revert SherwoodErrors.NoWithdrawableBalance();

        protocolFeesAccrued = 0;
        _sendNative(feeRecipient, amount);
        emit ProtocolFeeCollected(address(this), feeRecipient, amount);
    }

    // ── Owner (creator) pause ─────────────────────────────────────────────────

    /// @notice Pause buy() and claim(). Does not affect refund() or withdrawals.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resume buy() and claim() after a pause.
    function unpause() external onlyOwner {
        _unpause();
    }

    // ── Views ─────────────────────────────────────────────────────────────────

    /// @notice Returns the token amount a given contribution of `nativeAmount` would buy.
    ///         Returns 0 if the amount does not divide evenly by tokenPrice.
    function quoteTokens(uint256 nativeAmount) external view returns (uint256) {
        if (nativeAmount == 0) return 0;
        uint256 tokenAmt = Math.mulDiv(nativeAmount, LaunchConstants.WAD, tokenPrice);
        if (Math.mulDiv(tokenAmt, tokenPrice, LaunchConstants.WAD) != nativeAmount) return 0;
        return tokenAmt;
    }

    /// @notice Returns the remaining token supply available for purchase.
    function remainingAllocation() external view returns (uint256) {
        return tokenAllocation > totalTokensReserved
            ? tokenAllocation - totalTokensReserved
            : 0;
    }

    /// @notice Returns the remaining headroom before the hard cap is reached.
    function remainingHardCap() external view returns (uint256) {
        return hardCap > totalRaised ? hardCap - totalRaised : 0;
    }

    // ── Internal helpers ─────────────────────────────────────────────────────

    /// @dev Recomputes protocol fee and creator proceeds from current totalRaised.
    ///      Called after every buy(). Both are only withdrawable post-graduation.
    function _syncProceeds() private {
        protocolFeesAccrued    = Math.mulDiv(totalRaised, protocolFeeBps, LaunchConstants.BPS_DENOMINATOR);
        creatorProceedsAccrued = totalRaised - protocolFeesAccrued;
    }

    /// @dev Notifies the factory that this launch has reached a terminal state.
    ///      If the factory call reverts (e.g. factory is upgraded and incompatible),
    ///      we catch silently — the launch lifecycle must not be blocked by a
    ///      factory-side issue.
    function _noteTerminal() private {
        try ILaunchFactory(factory).noteTerminal() {} catch {}
    }

    /// @dev Low-level ETH transfer. Reverts with NativeTransferFailed on failure.
    function _sendNative(address recipient, uint256 amount) private {
        (bool ok,) = payable(recipient).call{value: amount}("");
        if (!ok) revert SherwoodErrors.NativeTransferFailed();
    }
}
