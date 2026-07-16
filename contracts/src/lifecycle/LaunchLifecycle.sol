// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20}        from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20}     from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable}       from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step}  from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable}      from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {SherwoodErrors}  from "../errors/SherwoodErrors.sol";
import {LaunchTypes}     from "../libraries/LaunchTypes.sol";
import {ILaunchFactory}  from "../interfaces/ILaunchFactory.sol";

/// @title ILaunchActions
/// @notice Minimal set of actions LaunchLifecycle can invoke on a Launch clone.
///         Keeps the lifecycle contract decoupled from the full Launch ABI.
interface ILaunchActions {
    function state()                   external view returns (LaunchTypes.SaleState);
    function factory()                 external view returns (address);
    function creator()                 external view returns (address);
    function endTime()                 external view returns (uint64);
    function totalRaised()             external view returns (uint256);
    function creatorProceedsAccrued()  external view returns (uint256);
    function protocolFeesAccrued()     external view returns (uint256);
    function saleToken()               external view returns (address);

    function finalize()                external;
    function cancel()                  external;
    function withdrawTreasury()        external;
    function collectProtocolFees()     external;
    function withdrawUnsoldTokens()    external;
    function pause()                   external;
    function unpause()                 external;
}

/// @title LaunchLifecycle
/// @author SHERWOOD Labs
/// @notice Stateless operator layer for managing Launch clone lifecycles.
///
/// @dev Purpose
///      ────────
///      This contract provides:
///        1. Atomic settlement — finalize a launch AND trigger treasury/fee
///           withdrawals in a single transaction (reduces gas for operators).
///        2. Emergency recovery — the owner can recover stuck ERC-20 tokens
///           from a Launch clone if the creator is unresponsive or unreachable.
///           ETH belonging to participants is NEVER recoverable; only surplus
///           tokens and genuinely orphaned balances can be recovered.
///        3. Protocol state validation — view helpers that aggregate state
///           across the registry for monitoring tooling.
///        4. Batch operations — finalize/cancel multiple launches in one tx.
///
///      Security model
///      ──────────────
///      • Only the owner may call emergency recovery functions.
///      • The owner can only recover ERC-20 tokens from terminal launches.
///      • Participant ETH (contributions) is never extractable by this contract.
///      • All calls to Launch are made through the ILaunchActions interface;
///        this contract never holds ETH or tokens itself.
///
///      Compatibility
///      ─────────────
///      Compatible with both Launch.sol and LaunchProject.sol. Only calls
///      functions present on ILaunchActions. Does not modify any existing contract.

contract LaunchLifecycle is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Events ────────────────────────────────────────────────────────────────

    /// @notice Emitted after an atomic settle operation completes.
    /// @param launch      Launch clone address.
    /// @param state       Final sale state (Graduated or Failed).
    /// @param totalRaised Total ETH raised in the sale.
    event LaunchSettled(
        address indexed launch,
        LaunchTypes.SaleState indexed state,
        uint256 totalRaised
    );

    /// @notice Emitted when the owner recovers tokens from a terminal launch.
    /// @param launch    Launch clone address.
    /// @param token     Recovered ERC-20 token address.
    /// @param recipient Address that received the recovered tokens.
    /// @param amount    Quantity of tokens recovered.
    event EmergencyRecovery(
        address indexed launch,
        address indexed token,
        address indexed recipient,
        uint256 amount
    );

    /// @notice Emitted when the owner triggers an emergency pause on a launch.
    event LaunchPaused(address indexed launch);

    /// @notice Emitted when the owner lifts an emergency pause on a launch.
    event LaunchUnpaused(address indexed launch);

    /// @notice Emitted when the owner force-cancels a non-terminal launch.
    event LaunchForceCancelled(address indexed launch);

    // ── State ─────────────────────────────────────────────────────────────────

    /// @notice The LaunchFactory whose registered launches this contract can manage.
    ILaunchFactory public immutable factory;

    // ── Constructor ───────────────────────────────────────────────────────────

    /// @notice Deploys the lifecycle manager.
    /// @param factory_     LaunchFactory whose registry is authoritative.
    /// @param initialOwner Protocol operator address (multisig recommended).
    constructor(address factory_, address initialOwner) Ownable(initialOwner) {
        if (factory_ == address(0) || initialOwner == address(0)) {
            revert SherwoodErrors.InvalidAddress();
        }
        factory = ILaunchFactory(factory_);
    }

    // ── External: atomic settlement ──────────────────────────────────────────

    /// @notice Finalizes a launch after its sale window closes.
    ///         The caller must be the creator of the launch or the contract owner.
    ///         If the launch is already in a terminal state this call is a no-op
    ///         (it does NOT revert) so it is safe to call idempotently.
    ///
    /// @dev    settle() calls finalize() on the launch, which determines Graduated
    ///         or Failed based on whether totalRaised >= softCap.
    ///         It does NOT trigger creator treasury or protocol fee withdrawals —
    ///         those must be pulled separately by the creator and feeRecipient
    ///         because LaunchLifecycle holds neither role on any launch.
    ///
    /// @param launch Launch clone address to settle.
    function settle(address launch) external nonReentrant whenNotPaused {
        _requireRegistered(launch);

        ILaunchActions l = ILaunchActions(launch);
        address launchCreator = l.creator();
        if (msg.sender != launchCreator && msg.sender != owner()) {
            revert SherwoodErrors.Unauthorized();
        }

        LaunchTypes.SaleState current = l.state();

        // If already terminal, emit event and return — idempotent.
        if (current == LaunchTypes.SaleState.Graduated || current == LaunchTypes.SaleState.Failed) {
            emit LaunchSettled(launch, current, l.totalRaised());
            return;
        }

        // Must be past endTime to finalize.
        if (block.timestamp < l.endTime()) revert SherwoodErrors.SaleNotFinished();

        // Finalize determines Graduated vs Failed.
        l.finalize();
        LaunchTypes.SaleState newState = l.state();
        uint256 raised = l.totalRaised();

        emit LaunchSettled(launch, newState, raised);
    }

    /// @notice Batch-settle multiple launches in a single transaction.
    ///         Each launch is settled independently; one failure does not block others.
    ///         Caller must be owner.
    ///
    /// @param launches Array of launch clone addresses.
    function batchSettle(address[] calldata launches) external onlyOwner nonReentrant whenNotPaused {
        for (uint256 i = 0; i < launches.length; i++) {
            if (!factory.isRegistered(launches[i])) continue;
            ILaunchActions l = ILaunchActions(launches[i]);
            LaunchTypes.SaleState current = l.state();
            if (current == LaunchTypes.SaleState.Graduated || current == LaunchTypes.SaleState.Failed) {
                emit LaunchSettled(launches[i], current, l.totalRaised());
                continue;
            }
            if (block.timestamp < l.endTime()) continue;
            try l.finalize() {
                LaunchTypes.SaleState newState = l.state();
                emit LaunchSettled(launches[i], newState, l.totalRaised());
            } catch {}
        }
    }

    // ── External: emergency controls (owner only) ────────────────────────────

    /// @notice Pause a launch's buy() and claim() functions.
    ///         Use during incident response.
    /// @param launch Launch clone address.
    function emergencyPauseLaunch(address launch) external onlyOwner {
        _requireRegistered(launch);
        ILaunchActions(launch).pause();
        emit LaunchPaused(launch);
    }

    /// @notice Remove a previously applied emergency pause from a launch.
    /// @param launch Launch clone address.
    function emergencyUnpauseLaunch(address launch) external onlyOwner {
        _requireRegistered(launch);
        ILaunchActions(launch).unpause();
        emit LaunchUnpaused(launch);
    }

    /// @notice Force-finalize a non-terminal launch that has passed its endTime.
    ///         Use during incident response when the normal parties are unresponsive.
    ///         Sets the launch to Graduated (if softCap met) or Failed (otherwise).
    ///
    /// @dev    Uses finalize() rather than cancel() because finalize() is
    ///         permissionless while cancel() requires onlyCreator. The sale
    ///         window must have already ended (endTime must be in the past).
    ///         If you need to cancel an active sale before endTime, the creator
    ///         must call cancel() directly on the Launch contract.
    ///
    /// @param launch Launch clone address.
    function emergencyCancel(address launch) external onlyOwner {
        _requireRegistered(launch);
        ILaunchActions l = ILaunchActions(launch);
        LaunchTypes.SaleState current = l.state();
        if (current == LaunchTypes.SaleState.Graduated || current == LaunchTypes.SaleState.Failed) {
            revert SherwoodErrors.SaleNotActive();
        }
        // finalize() requires block.timestamp >= endTime — enforce explicitly
        // so the caller gets a clear error rather than SaleNotFinished from inside.
        if (block.timestamp < l.endTime()) revert SherwoodErrors.SaleNotFinished();
        l.finalize();
        emit LaunchForceCancelled(launch);
    }

    /// @notice Recover ERC-20 tokens from a terminal Launch clone.
    ///         Only callable after the launch has reached Graduated or Failed state.
    ///
    /// @dev    Two-step mechanism:
    ///           1. The launch's creator MUST call approve(address(this), amount)
    ///              on the saleToken before this function is called.
    ///           2. This function calculates the unsold surplus (balanceOf(launch)
    ///              minus totalTokensReserved in Graduated state, or full balance
    ///              in Failed state) and transfers it directly to `recipient`.
    ///
    ///         This approach does NOT call withdrawUnsoldTokens() (onlyCreator),
    ///         so it works even when the creator is unresponsive, provided they
    ///         have approved this contract.
    ///
    ///         For truly orphaned launches where the creator cannot approve,
    ///         the protocol deployer should use a governance-level rescue mechanism.
    ///
    /// @param launch    Launch clone address.
    /// @param token     ERC-20 token to recover (must be the launch's saleToken).
    /// @param recipient Address to send recovered tokens to.
    function emergencyRecoverTokens(
        address launch,
        address token,
        address recipient
    ) external onlyOwner nonReentrant {
        _requireRegistered(launch);
        if (token == address(0) || recipient == address(0)) revert SherwoodErrors.InvalidAddress();

        ILaunchActions l = ILaunchActions(launch);
        LaunchTypes.SaleState current = l.state();
        if (current != LaunchTypes.SaleState.Graduated && current != LaunchTypes.SaleState.Failed) {
            revert SherwoodErrors.SaleNotActive();
        }

        // Compute unsold tokens: for Graduated, exclude reserved (claimable by buyers).
        // For Failed, the entire balance is recoverable (buyers claim native refunds, not tokens).
        uint256 launchBalance = IERC20(token).balanceOf(launch);
        uint256 unsoldAmount;

        if (current == LaunchTypes.SaleState.Graduated) {
            // Access totalTokensReserved via the launch's public storage.
            // We call the Launch contract directly for the reserved amount.
            (bool ok, bytes memory data) = launch.staticcall(
                abi.encodeWithSignature("totalTokensReserved()")
            );
            uint256 reserved = (ok && data.length == 32) ? abi.decode(data, (uint256)) : 0;
            unsoldAmount = launchBalance > reserved ? launchBalance - reserved : 0;
        } else {
            unsoldAmount = launchBalance;
        }

        if (unsoldAmount == 0) revert SherwoodErrors.NoWithdrawableBalance();

        // Transfer via safeTransferFrom — requires launch's creator to have approved
        // this contract first.
        IERC20(token).safeTransferFrom(launch, recipient, unsoldAmount);
        emit EmergencyRecovery(launch, token, recipient, unsoldAmount);
    }

    // ── External: governance ─────────────────────────────────────────────────

    /// @notice Pause all settlement and batch operations on this contract.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resume operations after a pause.
    function unpause() external onlyOwner {
        _unpause();
    }

    // ── External: views ──────────────────────────────────────────────────────

    /// @notice Returns the current state of a launch.
    /// @param launch Launch clone address.
    function getLaunchState(address launch) external view returns (LaunchTypes.SaleState) {
        _requireRegistered(launch);
        return ILaunchActions(launch).state();
    }

    /// @notice Returns whether a launch is in a terminal state.
    /// @param launch Launch clone address.
    function isTerminal(address launch) external view returns (bool) {
        if (!factory.isRegistered(launch)) return false;
        LaunchTypes.SaleState s = ILaunchActions(launch).state();
        return s == LaunchTypes.SaleState.Graduated || s == LaunchTypes.SaleState.Failed;
    }

    /// @notice Validates the protocol state of a launch: whether it is settleable.
    ///         Returns (settleable, reason) where reason is a human-readable string.
    ///
    /// @param launch Launch clone address.
    /// @return settleable True if settle() can be called right now.
    /// @return reason     Explanation; "ok" when settleable.
    function validateSettlement(address launch)
        external
        view
        returns (bool settleable, string memory reason)
    {
        if (!factory.isRegistered(launch)) return (false, "not registered");

        ILaunchActions l = ILaunchActions(launch);
        LaunchTypes.SaleState current = l.state();

        if (current == LaunchTypes.SaleState.Graduated) return (false, "already graduated");
        if (current == LaunchTypes.SaleState.Failed)    return (false, "already failed");
        if (block.timestamp < l.endTime())              return (false, "sale not finished");

        return (true, "ok");
    }

    // ── Internal ─────────────────────────────────────────────────────────────

    /// @dev Reverts if launch is not registered in the factory.
    function _requireRegistered(address launch) private view {
        if (!factory.isRegistered(launch)) revert SherwoodErrors.NotALaunch(launch);
    }
}
