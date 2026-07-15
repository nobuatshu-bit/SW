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

/// @title LaunchProject
/// @notice A fixed-price native-asset launch sale deployed by SherwoodFactory clones.
/// @dev The contract deliberately does not implement a bonding curve. Funds are only withdrawable
/// after graduation, preserving complete refunds if a project is cancelled.
contract LaunchProject is ILaunchProject, SherwoodEvents, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bool private _initialized;

    address public factory;
    address public creator;
    address public feeRecipient;
    IERC20 public saleToken;
    LaunchTypes.ProjectState public state;

    uint16 public protocolFeeBps;
    uint64 public startTime;
    uint64 public endTime;
    uint256 public saleTokenAllocation;
    uint256 public tokenPrice;
    uint256 public softCap;
    uint256 public maxRaise;
    uint256 public totalRaised;
    uint256 public totalOutstandingTokens;
    uint256 public protocolFeesAccrued;
    uint256 public creatorProceedsAccrued;

    mapping(address account => uint256 amount) public purchasedTokens;
    mapping(address account => uint256 amount) public contributions;

    modifier onlyCreator() {
        if (msg.sender != creator) revert SherwoodErrors.Unauthorized();
        _;
    }

    modifier onlyFeeRecipient() {
        if (msg.sender != feeRecipient) revert SherwoodErrors.Unauthorized();
        _;
    }

    /// @dev Locks the implementation instance. Clone storage starts uninitialized.
    constructor() {
        _initialized = true;
    }

    receive() external payable {
        revert SherwoodErrors.InvalidPaymentAmount();
    }

    /// @notice Initializes a factory-created minimal proxy exactly once.
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

    /// @notice Moves a scheduled project from Pending to Live once its start time arrives.
    function activate() external {
        if (state != LaunchTypes.ProjectState.Pending) revert SherwoodErrors.InvalidProjectState(state);
        if (block.timestamp < startTime) revert SherwoodErrors.SaleNotStarted();
        if (block.timestamp >= endTime) revert SherwoodErrors.SaleAlreadyEnded();

        state = LaunchTypes.ProjectState.Live;
        emit LaunchActivated(address(this), block.timestamp);
    }

    /// @notice Buys launch tokens at a fixed native-asset price.
    /// @dev Payment must map exactly to token precision, preventing value trapped by division rounding.
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

    /// @notice Sells unclaimed purchased allocation back to the launch during the Live state.
    function sell(uint256 tokenAmount) external nonReentrant {
        _requireLiveSale();
        if (tokenAmount == 0) revert SherwoodErrors.InvalidTokenAmount();
        if (purchasedTokens[msg.sender] < tokenAmount) revert SherwoodErrors.InvalidTokenAmount();

        uint256 refundAmount = Math.mulDiv(tokenAmount, tokenPrice, LaunchConstants.WAD);
        if (refundAmount == 0 || contributions[msg.sender] < refundAmount) {
            revert SherwoodErrors.InvalidTokenAmount();
        }

        purchasedTokens[msg.sender] -= tokenAmount;
        contributions[msg.sender] -= refundAmount;
        totalOutstandingTokens -= tokenAmount;
        totalRaised -= refundAmount;
        _syncProceeds();

        _sendNative(msg.sender, refundAmount);
        emit TokensSold(address(this), msg.sender, refundAmount, tokenAmount);
    }

    /// @notice Finalizes the launch after the sale window. A launch graduates when it reaches soft cap.
    function finalize() external {
        if (state != LaunchTypes.ProjectState.Pending && state != LaunchTypes.ProjectState.Live) {
            revert SherwoodErrors.InvalidProjectState(state);
        }
        if (block.timestamp < endTime) revert SherwoodErrors.SaleNotFinished();

        state = totalRaised >= softCap ? LaunchTypes.ProjectState.Graduated : LaunchTypes.ProjectState.Cancelled;
        emit LaunchFinalized(address(this), state, totalRaised);
    }

    /// @notice Cancels an active or scheduled launch before its scheduled end time.
    function cancel() external onlyCreator {
        if (state != LaunchTypes.ProjectState.Pending && state != LaunchTypes.ProjectState.Live) {
            revert SherwoodErrors.InvalidProjectState(state);
        }
        if (block.timestamp >= endTime) revert SherwoodErrors.SaleAlreadyEnded();

        state = LaunchTypes.ProjectState.Cancelled;
        emit LaunchCancelled(address(this), msg.sender);
    }

    /// @notice Claims purchased tokens after graduation, or a native-asset refund after cancellation.
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

    /// @notice Transfers the final protocol fee to the configured recipient after graduation.
    function collectProtocolFees() external onlyFeeRecipient nonReentrant {
        if (state != LaunchTypes.ProjectState.Graduated) revert SherwoodErrors.InvalidProjectState(state);
        uint256 amount = protocolFeesAccrued;
        if (amount == 0) revert SherwoodErrors.NoWithdrawableBalance();

        protocolFeesAccrued = 0;
        _sendNative(feeRecipient, amount);
        emit ProtocolFeeCollected(address(this), feeRecipient, amount);
    }

    /// @notice Transfers creator proceeds held in treasury after a successful launch.
    function withdrawTreasury() external onlyCreator nonReentrant {
        if (state != LaunchTypes.ProjectState.Graduated) revert SherwoodErrors.InvalidProjectState(state);
        uint256 amount = creatorProceedsAccrued;
        if (amount == 0) revert SherwoodErrors.NoWithdrawableBalance();

        creatorProceedsAccrued = 0;
        _sendNative(creator, amount);
        emit TreasuryWithdrawn(address(this), creator, amount);
    }

    /// @notice Returns unsold launch tokens to the creator without affecting buyer claims.
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

    function _requireLiveSale() private view {
        if (state != LaunchTypes.ProjectState.Live) revert SherwoodErrors.SaleNotLive();
        if (block.timestamp >= endTime) revert SherwoodErrors.SaleEnded();
    }

    function _syncProceeds() private {
        protocolFeesAccrued = Math.mulDiv(totalRaised, protocolFeeBps, LaunchConstants.BPS_DENOMINATOR);
        creatorProceedsAccrued = totalRaised - protocolFeesAccrued;
    }

    function _sendNative(address recipient, uint256 amount) private {
        (bool success,) = payable(recipient).call{value: amount}("");
        if (!success) revert SherwoodErrors.NativeTransferFailed();
    }
}
