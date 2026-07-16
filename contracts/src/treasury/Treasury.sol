// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {SherwoodErrors} from "../errors/SherwoodErrors.sol";
import {LaunchConstants} from "../utils/LaunchConstants.sol";

/// @title  Treasury
/// @author SHERWOOD Labs
/// @notice Protocol and creator fee aggregator for SHERWOOD launch sales.
///
/// @dev    Role summary
///         ─────────────
///         • Owner (protocol multisig) — controls fee splits, registered senders,
///           emergency pause, and direct top-ups via receive().
///         • Registered senders (graduated Launch clones) — the only addresses
///           allowed to call deposit(), keeping the accounting surface minimal.
///         • Fee recipients — addresses that receive a configured share of each
///           deposit. Up to MAX_RECIPIENTS entries per split.
///
///         Deposit flow
///         ────────────
///         1. A graduated Launch calls collectProtocolFees() which sends ETH here.
///            Treasury is deployed as the feeRecipient for new launches.
///         2. deposit(creator) distributes msg.value among configured recipients
///            by incrementing their `allocations` entries. No ETH is pushed
///            automatically — recipients pull funds via withdraw() / withdrawPartial().
///
///         Fee split invariant
///         ────────────────────
///         All shareBps values in the active split must sum to exactly
///         BPS_DENOMINATOR (10 000). This invariant is enforced at setFeeSplit()
///         time and never violated at runtime.
///         If no split is configured, the entire deposit credits the owner.
///
///         Ownership change caveat
///         ────────────────────────
///         allocations are stored per-address. If ownership is transferred via
///         Ownable2Step, ETH credited to the old owner's slot before the transfer
///         remains claimable by that old owner. The new owner's slot starts at zero.
///         To consolidate funds, the old owner should withdraw before the transfer,
///         or the protocol should ensure the allocation is zero first.
///
///         Reentrancy
///         ──────────
///         All ETH-sending paths are guarded by {ReentrancyGuard} and follow the
///         Checks-Effects-Interactions pattern.
contract Treasury is Ownable2Step, Pausable, ReentrancyGuard {

    // ── Constants ─────────────────────────────────────────────────────────────

    /// @notice Maximum number of fee-split recipient entries.
    uint256 public constant MAX_RECIPIENTS = 10;

    // ── Events ────────────────────────────────────────────────────────────────

    /// @notice Emitted on every ETH deposit from a registered sender.
    /// @param sender      The registered Launch clone that called deposit().
    /// @param creator     The creator address passed by the Launch clone for off-chain context.
    /// @param totalAmount Total ETH received in this deposit.
    event Deposited(address indexed sender, address indexed creator, uint256 totalAmount);

    /// @notice Emitted when a recipient withdraws their accumulated allocation.
    /// @param recipient Address that withdrew.
    /// @param amount    ETH amount withdrawn.
    event Withdrawn(address indexed recipient, uint256 amount);

    /// @notice Emitted when the fee split configuration is updated.
    event FeeSplitUpdated(FeeSplitEntry[] newSplit);

    /// @notice Emitted when a sender is registered or deregistered.
    event SenderRegistrationUpdated(address indexed sender, bool registered);

    // ── Types ─────────────────────────────────────────────────────────────────

    /// @notice A single entry in the fee-split configuration.
    /// @param recipient  Address that receives a share of each deposit.
    /// @param shareBps   Share in basis points. All entries must sum to BPS_DENOMINATOR.
    struct FeeSplitEntry {
        address recipient;
        uint16 shareBps;
    }

    // ── State ─────────────────────────────────────────────────────────────────

    /// @notice Accumulated ETH balance per address, withdrawable at any time.
    mapping(address => uint256) public allocations;

    /// @dev Current fee-split configuration. Empty means 100% to owner.
    FeeSplitEntry[] private _feeSplit;

    /// @dev Addresses authorised to call deposit(). Typically graduated Launch clones.
    mapping(address => bool) private _registeredSenders;

    // ── Constructor ───────────────────────────────────────────────────────────

    /// @notice Deploys the treasury.
    /// @param initialOwner Protocol multisig or deployer address. Cannot be zero.
    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert SherwoodErrors.InvalidAddress();
    }

    // ── Receive ───────────────────────────────────────────────────────────────

    /// @dev Accepts plain ETH transfers (e.g. owner topping up the contract) and
    ///      credits them to the current owner's allocation.
    ///      Note: if ownership is later transferred, this ETH remains in the old
    ///      owner's allocation slot and is claimable by them via withdraw().
    receive() external payable {
        if (msg.value > 0) {
            allocations[owner()] += msg.value;
            emit Deposited(msg.sender, address(0), msg.value);
        }
    }

    // ── External: deposit (registered senders only) ───────────────────────────

    /// @notice Distributes incoming ETH among the configured fee-split recipients.
    ///         Funds are credited to recipient allocations; no ETH is pushed immediately.
    ///         Must be called by a registered sender (a graduated Launch clone).
    ///
    /// @dev    The last recipient in the split receives `total - distributed` to absorb
    ///         any mulDiv rounding dust and ensure no ETH is stranded.
    ///         CEI: all allocation writes happen before the event is emitted.
    ///
    /// @param creator Creator address of the originating launch (for off-chain indexing).
    function deposit(address creator) external payable whenNotPaused nonReentrant {
        if (!_registeredSenders[msg.sender]) revert SherwoodErrors.NotALaunch(msg.sender);
        if (msg.value == 0) revert SherwoodErrors.InvalidPaymentAmount();

        uint256 total = msg.value;
        uint256 len = _feeSplit.length;

        if (len == 0) {
            // No split configured: entire deposit goes to owner.
            allocations[owner()] += total;
        } else {
            uint256 distributed = 0;
            for (uint256 i = 0; i < len - 1; i++) {
                uint256 share = Math.mulDiv(total, _feeSplit[i].shareBps, LaunchConstants.BPS_DENOMINATOR);
                allocations[_feeSplit[i].recipient] += share;
                distributed += share;
            }
            // Last recipient absorbs rounding remainder (no dust loss).
            allocations[_feeSplit[len - 1].recipient] += total - distributed;
        }

        emit Deposited(msg.sender, creator, total);
    }

    // ── External: withdraw ────────────────────────────────────────────────────

    /// @notice Withdraws the caller's full accumulated allocation.
    ///         Reverts if the caller has no claimable balance.
    ///         CEI: allocation zeroed before transfer.
    function withdraw() external whenNotPaused nonReentrant {
        uint256 amount = allocations[msg.sender];
        if (amount == 0) revert SherwoodErrors.NoWithdrawableBalance();

        allocations[msg.sender] = 0;

        _sendNative(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Withdraws a specific `amount` from the caller's accumulated allocation.
    ///         Reverts if `amount` is zero or exceeds the caller's balance.
    ///         CEI: allocation decremented before transfer.
    /// @param amount ETH amount to withdraw. Must be <= allocations[caller].
    function withdrawPartial(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert SherwoodErrors.InvalidPaymentAmount();
        if (allocations[msg.sender] < amount) revert SherwoodErrors.NoWithdrawableBalance();

        allocations[msg.sender] -= amount;

        _sendNative(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    // ── External: governance ─────────────────────────────────────────────────

    /// @notice Configures the fee-split applied to every future deposit.
    ///         All shareBps values must sum to exactly BPS_DENOMINATOR (10 000).
    ///         Pass an empty array to route 100% of deposits to the owner.
    ///         The number of entries must not exceed MAX_RECIPIENTS.
    /// @param  newSplit  Array of (recipient, shareBps) pairs.
    function setFeeSplit(FeeSplitEntry[] calldata newSplit) external onlyOwner {
        uint256 len = newSplit.length;
        if (len > MAX_RECIPIENTS) revert SherwoodErrors.InvalidRecipientCount();

        if (len > 0) {
            uint256 totalBps = 0;
            for (uint256 i = 0; i < len; i++) {
                if (newSplit[i].recipient == address(0)) revert SherwoodErrors.InvalidAddress();
                if (newSplit[i].shareBps == 0) revert SherwoodErrors.InvalidAllocation();
                totalBps += newSplit[i].shareBps;
            }
            if (totalBps != LaunchConstants.BPS_DENOMINATOR) {
                revert SherwoodErrors.RecipientSharesMismatch();
            }
        }

        // Replace stored split.
        delete _feeSplit;
        for (uint256 i = 0; i < len; i++) {
            _feeSplit.push(newSplit[i]);
        }

        emit FeeSplitUpdated(newSplit);
    }

    /// @notice Registers or deregisters a single sender address.
    ///         Only registered senders may call deposit().
    ///         Typically called after a new Launch clone is deployed, or to
    ///         disable a compromised address.
    /// @param sender     Address to update. Cannot be zero.
    /// @param registered True to authorise, false to revoke.
    function setSenderRegistration(address sender, bool registered) external onlyOwner {
        if (sender == address(0)) revert SherwoodErrors.InvalidAddress();
        _registeredSenders[sender] = registered;
        emit SenderRegistrationUpdated(sender, registered);
    }

    /// @notice Bulk-registers multiple sender addresses in a single transaction.
    ///         All addresses are set to registered = true.
    ///         Reverts if any address in the array is the zero address.
    /// @param senders Array of addresses to register.
    function registerSenders(address[] calldata senders) external onlyOwner {
        for (uint256 i = 0; i < senders.length; i++) {
            if (senders[i] == address(0)) revert SherwoodErrors.InvalidAddress();
            _registeredSenders[senders[i]] = true;
            emit SenderRegistrationUpdated(senders[i], true);
        }
    }

    /// @notice Pauses deposit() and withdraw(). For emergency use only.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes deposit() and withdraw() after a pause.
    function unpause() external onlyOwner {
        _unpause();
    }

    // ── External: views ──────────────────────────────────────────────────────

    /// @notice Returns the current fee-split configuration.
    function getFeeSplit() external view returns (FeeSplitEntry[] memory) {
        return _feeSplit;
    }

    /// @notice Returns whether a sender address is registered.
    /// @param sender Address to check.
    function isRegisteredSender(address sender) external view returns (bool) {
        return _registeredSenders[sender];
    }

    /// @notice Returns the total ETH held in the contract.
    function totalBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ── Internal ─────────────────────────────────────────────────────────────

    /// @dev Low-level native-asset transfer. Reverts with NativeTransferFailed on failure.
    ///      Uses a call with empty data to support recipients without fallback gas restrictions.
    function _sendNative(address recipient, uint256 amount) private {
        (bool ok,) = payable(recipient).call{value: amount}("");
        if (!ok) revert SherwoodErrors.NativeTransferFailed();
    }
}
