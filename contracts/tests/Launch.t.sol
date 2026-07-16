// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test}     from "forge-std/Test.sol";
import {Ownable}  from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20}    from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Launch}          from "../src/launchpad/Launch.sol";
import {LaunchFactory}   from "../src/factory/LaunchFactory.sol";
import {SherwoodErrors}  from "../src/errors/SherwoodErrors.sol";
import {LaunchTypes}     from "../src/libraries/LaunchTypes.sol";
import {LaunchConstants} from "../src/utils/LaunchConstants.sol";

// ── Minimal ERC-20 for tests ──────────────────────────────────────────────────
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

// ── Launch test suite ─────────────────────────────────────────────────────────
contract LaunchTest is Test {

    // ── Actors ────────────────────────────────────────────────────────────────
    address internal owner        = makeAddr("owner");
    address internal creator      = makeAddr("creator");
    address internal feeRecipient = makeAddr("feeRecipient");
    address internal buyer1       = makeAddr("buyer1");
    address internal buyer2       = makeAddr("buyer2");
    address internal stranger     = makeAddr("stranger");

    // ── Contracts ─────────────────────────────────────────────────────────────
    MockToken     internal token;
    Launch        internal impl;
    Launch        internal launch;
    LaunchFactory internal factory;

    // ── Sale parameters ───────────────────────────────────────────────────────
    uint16  internal constant FEE_BPS     = 500;
    uint256 internal constant TOKEN_PRICE = 0.001 ether;
    uint256 internal constant ALLOCATION  = 1_000_000 ether;
    uint256 internal constant SOFT_CAP    = 10 ether;
    uint256 internal constant HARD_CAP    = 100 ether;
    uint256 internal constant MIN_CONTRIB = 0.1 ether;
    uint256 internal constant MAX_CONTRIB = 10 ether;

    // ── Setup ─────────────────────────────────────────────────────────────────
    function setUp() external {
        token   = new MockToken();
        impl    = new Launch();
        factory = new LaunchFactory(owner, address(impl), feeRecipient, FEE_BPS);

        vm.prank(creator);
        address launchAddr = factory.createLaunch(_params());
        launch = Launch(payable(launchAddr));

        // Fund the launch contract with sale tokens
        token.mint(creator, ALLOCATION);
        vm.prank(creator);
        token.transfer(address(launch), ALLOCATION);

        vm.deal(buyer1,   1_000 ether);
        vm.deal(buyer2,   1_000 ether);
        vm.deal(stranger, 1_000 ether);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _params() internal view returns (LaunchTypes.LaunchParams memory) {
        return LaunchTypes.LaunchParams({
            name:            "Test Launch",
            description:     "desc",
            metadataURI:     "ipfs://Qm",
            token:           address(token),
            tokenPrice:      TOKEN_PRICE,
            tokenAllocation: ALLOCATION,
            softCap:         SOFT_CAP,
            hardCap:         HARD_CAP,
            minContribution: MIN_CONTRIB,
            maxContribution: MAX_CONTRIB,
            startTime:       uint64(block.timestamp + 1 hours),
            endTime:         uint64(block.timestamp + 2 hours)
        });
    }

    function _activate() internal {
        vm.warp(launch.startTime());
        launch.activate();
    }

    function _buy(address buyer, uint256 eth) internal {
        vm.prank(buyer);
        launch.buy{value: eth}();
    }

    function _finalize() internal {
        vm.warp(launch.endTime() + 1);
        launch.finalize();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Initialization
    // ══════════════════════════════════════════════════════════════════════════

    function test_InitializeSetsAllParameters() external view {
        assertEq(launch.factory(),               address(factory));
        assertEq(launch.creator(),               creator);
        assertEq(launch.feeRecipient(),          feeRecipient);
        assertEq(address(launch.saleToken()),    address(token));
        assertEq(launch.protocolFeeBps(),        FEE_BPS);
        assertEq(launch.tokenPrice(),            TOKEN_PRICE);
        assertEq(launch.tokenAllocation(),       ALLOCATION);
        assertEq(launch.softCap(),               SOFT_CAP);
        assertEq(launch.hardCap(),               HARD_CAP);
        assertEq(launch.minContribution(),       MIN_CONTRIB);
        assertEq(launch.maxContribution(),       MAX_CONTRIB);
        assertEq(uint8(launch.state()),          uint8(LaunchTypes.SaleState.Pending));
    }

    function test_InitializeRevertsOnSecondCall() external {
        LaunchTypes.LaunchParams memory p = _params();
        vm.expectRevert(SherwoodErrors.AlreadyInitialized.selector);
        launch.initialize(address(factory), creator, address(token), feeRecipient, FEE_BPS, p);
    }

    function test_ImplementationCannotBeInitialized() external {
        LaunchTypes.LaunchParams memory p = _params();
        vm.expectRevert(SherwoodErrors.AlreadyInitialized.selector);
        impl.initialize(address(factory), creator, address(token), feeRecipient, FEE_BPS, p);
    }

    function test_InitializeTransfersOwnershipToCreator() external view {
        assertEq(launch.owner(), creator);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Activate
    // ══════════════════════════════════════════════════════════════════════════

    function test_ActivateSetsActiveState() external {
        _activate();
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Active));
    }

    function test_ActivateEmitsEvent() external {
        vm.warp(launch.startTime());
        vm.expectEmit(true, false, false, false);
        emit Launch.SaleActivated(address(launch), uint64(block.timestamp));
        launch.activate();
    }

    function test_ActivateRevertsBeforeStartTime() external {
        vm.expectRevert(SherwoodErrors.SaleNotStarted.selector);
        launch.activate();
    }

    function test_ActivateRevertsAfterEndTime() external {
        vm.warp(launch.endTime() + 1);
        vm.expectRevert(SherwoodErrors.SaleAlreadyEnded.selector);
        launch.activate();
    }

    function test_ActivateRevertsWithoutTokenBalance() external {
        vm.prank(creator);
        address bare = factory.createLaunch(_params());
        // bare has no tokens deposited
        vm.warp(launch.startTime());
        vm.expectRevert(SherwoodErrors.TokenAllocationExceeded.selector);
        Launch(payable(bare)).activate();
    }

    function test_ActivateRevertsWhenAlreadyActive() external {
        _activate();
        vm.expectRevert(SherwoodErrors.SaleNotActive.selector);
        launch.activate();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Buy
    // ══════════════════════════════════════════════════════════════════════════

    function test_BuyReservesTokensAndTracksContribution() external {
        _activate();
        uint256 eth           = 1 ether;
        uint256 expectedTokens = eth * LaunchConstants.WAD / TOKEN_PRICE;

        vm.expectEmit(true, true, false, true);
        emit Launch.TokensPurchased(address(launch), buyer1, eth, expectedTokens);
        _buy(buyer1, eth);

        assertEq(launch.contributions(buyer1),   eth);
        assertEq(launch.purchasedTokens(buyer1), expectedTokens);
        assertEq(launch.totalRaised(),            eth);
        assertEq(launch.totalTokensReserved(),    expectedTokens);
    }

    function test_BuyRevertsWhenNotActive() external {
        vm.prank(buyer1);
        vm.expectRevert(SherwoodErrors.SaleNotActive.selector);
        launch.buy{value: 1 ether}();
    }

    function test_BuyRevertsAfterEndTime() external {
        _activate();
        vm.warp(launch.endTime());
        vm.prank(buyer1);
        vm.expectRevert(SherwoodErrors.SaleEnded.selector);
        launch.buy{value: 1 ether}();
    }

    function test_BuyRevertsOnZeroValue() external {
        _activate();
        vm.prank(buyer1);
        vm.expectRevert(SherwoodErrors.InvalidPaymentAmount.selector);
        launch.buy{value: 0}();
    }

    function test_BuyRevertsOnBelowMinContribution() external {
        _activate();
        vm.prank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.BelowMinContribution.selector, MIN_CONTRIB - 1, MIN_CONTRIB)
        );
        launch.buy{value: MIN_CONTRIB - 1}();
    }

    function test_BuyRevertsWhenExceedingMaxContribution() external {
        _activate();
        _buy(buyer1, MAX_CONTRIB);
        vm.prank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.MaxContributionExceeded.selector, MAX_CONTRIB + 0.1 ether, MAX_CONTRIB)
        );
        launch.buy{value: 0.1 ether}();
    }

    function test_BuyRevertsWhenExceedingHardCap() external {
        _activate();
        // Fill up to hard cap across many buyers
        uint256 filled = 0;
        for (uint256 i = 0; filled + MAX_CONTRIB <= HARD_CAP; i++) {
            address b = address(uint160(0xBEEF + i));
            vm.deal(b, 100 ether);
            vm.prank(b);
            launch.buy{value: MAX_CONTRIB}();
            filled += MAX_CONTRIB;
        }
        vm.prank(buyer2);
        vm.expectRevert(SherwoodErrors.MaximumRaiseExceeded.selector);
        launch.buy{value: 1 ether}();
    }

    function test_BuySyncsProceeds() external {
        _activate();
        _buy(buyer1, 10 ether);
        uint256 raised      = launch.totalRaised();
        uint256 expectedFee = raised * FEE_BPS / LaunchConstants.BPS_DENOMINATOR;
        assertEq(launch.protocolFeesAccrued(),    expectedFee);
        assertEq(launch.creatorProceedsAccrued(), raised - expectedFee);
    }

    function test_BuyRevertsWhenPaused() external {
        _activate();
        vm.prank(creator);
        launch.pause();
        vm.prank(buyer1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        launch.buy{value: 1 ether}();
    }

    function test_DirectEtherTransferReverts() external {
        (bool ok,) = payable(address(launch)).call{value: 1 ether}("");
        assertFalse(ok);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Finalize
    // ══════════════════════════════════════════════════════════════════════════

    function test_FinalizeGraduatesWhenSoftCapMet() external {
        _activate();
        _buy(buyer1, SOFT_CAP);
        _finalize();
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Graduated));
    }

    function test_FinalizeFailsWhenSoftCapNotMet() external {
        _activate();
        _buy(buyer1, SOFT_CAP - 0.001 ether);
        _finalize();
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Failed));
    }

    function test_FinalizeRevertsBeforeEndTime() external {
        _activate();
        vm.expectRevert(SherwoodErrors.SaleNotFinished.selector);
        launch.finalize();
    }

    function test_FinalizeOnPendingWithoutSoftCap() external {
        vm.warp(launch.endTime() + 1);
        launch.finalize();
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Failed));
    }

    function test_FinalizeNotifiesFactory() external {
        _activate();
        _buy(buyer1, SOFT_CAP);
        assertEq(factory.getActiveLaunchCount(creator), 1);
        _finalize();
        assertEq(factory.getActiveLaunchCount(creator), 0);
    }

    function test_FinalizeRevertsOnTerminalState() external {
        _finalize();
        vm.expectRevert(SherwoodErrors.SaleNotActive.selector);
        launch.finalize();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Cancel
    // ══════════════════════════════════════════════════════════════════════════

    function test_CancelSetsFailedState() external {
        _activate();
        vm.prank(creator);
        launch.cancel();
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Failed));
    }

    function test_CancelRevertsForNonCreator() external {
        _activate();
        vm.prank(stranger);
        vm.expectRevert(SherwoodErrors.Unauthorized.selector);
        launch.cancel();
    }

    function test_CancelRevertsAfterEndTime() external {
        _activate();
        vm.warp(launch.endTime());
        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.SaleAlreadyEnded.selector);
        launch.cancel();
    }

    function test_CancelNotifiesFactory() external {
        assertEq(factory.getActiveLaunchCount(creator), 1);
        vm.prank(creator);
        launch.cancel();
        assertEq(factory.getActiveLaunchCount(creator), 0);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Claim
    // ══════════════════════════════════════════════════════════════════════════

    function test_ClaimTransfersPurchasedTokens() external {
        _activate();
        _buy(buyer1, SOFT_CAP);
        _finalize();
        uint256 expected = launch.purchasedTokens(buyer1);
        uint256 before   = token.balanceOf(buyer1);
        vm.prank(buyer1);
        launch.claim();
        assertEq(token.balanceOf(buyer1),        before + expected);
        assertEq(launch.purchasedTokens(buyer1), 0);
    }

    function test_ClaimRevertsBeforeGraduation() external {
        _activate();
        _buy(buyer1, MIN_CONTRIB);
        vm.prank(buyer1);
        vm.expectRevert(SherwoodErrors.SaleNotActive.selector);
        launch.claim();
    }

    function test_ClaimRevertsWithNoBalance() external {
        _activate();
        _buy(buyer1, SOFT_CAP);
        _finalize();
        vm.prank(buyer2);
        vm.expectRevert(SherwoodErrors.NoClaimableBalance.selector);
        launch.claim();
    }

    function test_ClaimRevertsWhenPaused() external {
        _activate();
        _buy(buyer1, SOFT_CAP);
        _finalize();
        vm.prank(creator);
        launch.pause();
        vm.prank(buyer1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        launch.claim();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Refund
    // ══════════════════════════════════════════════════════════════════════════

    function test_RefundReturnsFundsAfterFailure() external {
        _activate();
        _buy(buyer1, MIN_CONTRIB);
        _finalize();
        uint256 before = buyer1.balance;
        vm.prank(buyer1);
        launch.refund();
        assertEq(buyer1.balance, before + MIN_CONTRIB);
        assertEq(launch.contributions(buyer1), 0);
    }

    function test_RefundRevertsBeforeFailure() external {
        _activate();
        _buy(buyer1, MIN_CONTRIB);
        vm.prank(buyer1);
        vm.expectRevert(SherwoodErrors.SaleNotActive.selector);
        launch.refund();
    }

    function test_RefundRevertsWithNoContribution() external {
        _finalize();
        vm.prank(buyer2);
        vm.expectRevert(SherwoodErrors.NoClaimableBalance.selector);
        launch.refund();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Treasury withdrawal
    // ══════════════════════════════════════════════════════════════════════════

    function test_WithdrawTreasuryTransfersProceedsToCreator() external {
        _activate();
        _buy(buyer1, SOFT_CAP);
        _finalize();
        uint256 expected = launch.creatorProceedsAccrued();
        uint256 before   = creator.balance;
        vm.prank(creator);
        launch.withdrawTreasury();
        assertEq(creator.balance, before + expected);
        assertEq(launch.creatorProceedsAccrued(), 0);
    }

    function test_WithdrawTreasuryRevertsBeforeGraduation() external {
        _activate();
        _buy(buyer1, MIN_CONTRIB);
        _finalize();
        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.SaleNotActive.selector);
        launch.withdrawTreasury();
    }

    function test_WithdrawTreasuryRevertsForNonCreator() external {
        _activate();
        _buy(buyer1, SOFT_CAP);
        _finalize();
        vm.prank(stranger);
        vm.expectRevert(SherwoodErrors.Unauthorized.selector);
        launch.withdrawTreasury();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Protocol fee
    // ══════════════════════════════════════════════════════════════════════════

    function test_CollectProtocolFeesTransfersFee() external {
        _activate();
        _buy(buyer1, SOFT_CAP);
        _finalize();
        uint256 expected = launch.protocolFeesAccrued();
        uint256 before   = feeRecipient.balance;
        vm.prank(feeRecipient);
        launch.collectProtocolFees();
        assertEq(feeRecipient.balance,         before + expected);
        assertEq(launch.protocolFeesAccrued(), 0);
    }

    function test_CollectProtocolFeesRevertsForNonRecipient() external {
        _activate();
        _buy(buyer1, SOFT_CAP);
        _finalize();
        vm.prank(stranger);
        vm.expectRevert(SherwoodErrors.Unauthorized.selector);
        launch.collectProtocolFees();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Unsold tokens
    // ══════════════════════════════════════════════════════════════════════════

    function test_WithdrawUnsoldTokensAfterGraduation() external {
        _activate();
        _buy(buyer1, SOFT_CAP);
        _finalize();
        uint256 reserved = launch.totalTokensReserved();
        uint256 balance  = token.balanceOf(address(launch));
        uint256 unsold   = balance - reserved;
        uint256 before   = token.balanceOf(creator);
        vm.prank(creator);
        launch.withdrawUnsoldTokens();
        assertEq(token.balanceOf(creator), before + unsold);
    }

    function test_WithdrawUnsoldTokensAfterFailure() external {
        _activate();
        _buy(buyer1, MIN_CONTRIB);
        _finalize();
        uint256 balance = token.balanceOf(address(launch));
        uint256 before  = token.balanceOf(creator);
        vm.prank(creator);
        launch.withdrawUnsoldTokens();
        assertEq(token.balanceOf(creator), before + balance);
    }

    function test_WithdrawUnsoldTokensRevertsForNonCreator() external {
        _finalize();
        vm.prank(stranger);
        vm.expectRevert(SherwoodErrors.Unauthorized.selector);
        launch.withdrawUnsoldTokens();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Views
    // ══════════════════════════════════════════════════════════════════════════

    function test_QuoteTokensComputesCorrectly() external view {
        assertEq(launch.quoteTokens(1 ether), 1 ether * LaunchConstants.WAD / TOKEN_PRICE);
    }

    function test_QuoteTokensReturnsZeroForZeroInput() external view {
        assertEq(launch.quoteTokens(0), 0);
    }

    function test_RemainingAllocationDecreasesOnBuy() external {
        _activate();
        uint256 before = launch.remainingAllocation();
        _buy(buyer1, MIN_CONTRIB);
        assertLt(launch.remainingAllocation(), before);
    }

    function test_RemainingHardCapDecreasesOnBuy() external {
        _activate();
        _buy(buyer1, 1 ether);
        assertEq(launch.remainingHardCap(), HARD_CAP - 1 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Fuzz
    // ══════════════════════════════════════════════════════════════════════════

    function testFuzz_BuyWithinLimitsAlwaysSucceeds(uint256 eth) external {
        _activate();
        // Align to token price granularity; clamp to [MIN, MAX]
        eth = bound(eth / TOKEN_PRICE * TOKEN_PRICE, MIN_CONTRIB, MAX_CONTRIB);
        vm.assume(eth >= MIN_CONTRIB);
        _buy(buyer1, eth);
        assertEq(launch.contributions(buyer1), eth);
    }
}
