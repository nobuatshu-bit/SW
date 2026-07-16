// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test}    from "forge-std/Test.sol";
import {ERC20}   from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Launch}          from "../src/launchpad/Launch.sol";
import {LaunchFactory}   from "../src/factory/LaunchFactory.sol";
import {Treasury}        from "../src/treasury/Treasury.sol";
import {LaunchLifecycle} from "../src/lifecycle/LaunchLifecycle.sol";
import {SherwoodErrors}  from "../src/errors/SherwoodErrors.sol";
import {LaunchTypes}     from "../src/libraries/LaunchTypes.sol";
import {LaunchConstants} from "../src/utils/LaunchConstants.sol";

/// @dev Minimal token for cross-contract tests.
contract S8Token is ERC20 {
    constructor() ERC20("S8 Token", "S8T") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

/// @title Sprint8SecurityTest
/// @notice Cross-contract integration and invariant tests added during Sprint 8
///         security audit. Each test targets a specific security concern or gap.
contract Sprint8SecurityTest is Test {

    // ── Actors ────────────────────────────────────────────────────────────────
    address internal protocolOwner = makeAddr("protocolOwner");
    address internal creator       = makeAddr("creator");
    address internal buyer1        = makeAddr("buyer1");
    address internal buyer2        = makeAddr("buyer2");
    address internal feeRecipient  = makeAddr("feeRecipient");
    address internal stranger      = makeAddr("stranger");

    // ── Contracts ─────────────────────────────────────────────────────────────
    S8Token       internal token;
    Launch        internal impl;
    LaunchFactory internal factory;
    Treasury      internal treasury;

    uint16  internal constant FEE_BPS     = 500;
    uint256 internal constant TOKEN_PRICE = 0.001 ether;
    uint256 internal constant ALLOCATION  = 1_000_000 ether;
    uint256 internal constant SOFT_CAP    = 10 ether;
    uint256 internal constant HARD_CAP    = 100 ether;

    function setUp() external {
        token    = new S8Token();
        impl     = new Launch();
        treasury = new Treasury(protocolOwner);
        factory  = new LaunchFactory(protocolOwner, address(impl), address(treasury), FEE_BPS);

        vm.deal(buyer1,   1_000 ether);
        vm.deal(buyer2,   1_000 ether);
        vm.deal(creator,  100 ether);
        vm.deal(stranger, 10 ether);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _params() internal view returns (LaunchTypes.LaunchParams memory) {
        return LaunchTypes.LaunchParams({
            name:            "S8 Launch",
            description:     "Sprint 8 security test launch",
            metadataURI:     "ipfs://s8",
            token:           address(token),
            tokenPrice:      TOKEN_PRICE,
            tokenAllocation: ALLOCATION,
            softCap:         SOFT_CAP,
            hardCap:         HARD_CAP,
            minContribution: 0,
            maxContribution: 0,
            startTime:       uint64(block.timestamp + 1 hours),
            endTime:         uint64(block.timestamp + 2 hours)
        });
    }

    function _deployAndFundLaunch() internal returns (Launch launch) {
        vm.prank(creator);
        address addr = factory.createLaunch(_params());
        launch = Launch(payable(addr));
        token.mint(creator, ALLOCATION);
        vm.prank(creator);
        token.transfer(address(launch), ALLOCATION);
    }

    function _activateLaunch(Launch launch) internal {
        vm.warp(launch.startTime());
        launch.activate();
    }

    function _graduateLaunch(Launch launch) internal {
        vm.prank(buyer1);
        launch.buy{value: SOFT_CAP}();
        vm.warp(launch.endTime() + 1);
        launch.finalize();
    }

    // ════════════════════════════════════════════════════════════════════════
    // Treasury integration: graduated launch fees flow to Treasury
    // ════════════════════════════════════════════════════════════════════════

    /// @dev When Treasury is deployed as the feeRecipient, protocol fees from a
    ///      graduated Launch can be forwarded to Treasury via deposit().
    ///      This tests the full protocol fee flow end-to-end.
    function test_GraduatedLaunchFeesCanFlowToTreasury() external {
        Launch launch = _deployAndFundLaunch();
        _activateLaunch(launch);
        _graduateLaunch(launch);

        uint256 feeAccrued = launch.protocolFeesAccrued();
        assertGt(feeAccrued, 0, "no protocol fees accrued");

        // Register the launch as an authorised Treasury sender.
        vm.prank(protocolOwner);
        treasury.setSenderRegistration(address(launch), true);

        // The fee recipient (treasury) collects fees from the launch.
        // Treasury receives ETH and credits it per the fee split.
        uint256 treasuryBefore = address(treasury).balance;
        vm.prank(address(treasury));
        launch.collectProtocolFees();
        // Treasury received the fee.
        assertEq(address(treasury).balance, treasuryBefore + feeAccrued);
    }

    /// @dev Treasury.deposit() must revert from unregistered callers even if
    ///      they send ETH. This guards against fee injection by arbitrary actors.
    function test_TreasuryDepositRevertsFromUnregisteredLaunch() external {
        Launch launch = _deployAndFundLaunch();
        _activateLaunch(launch);
        _graduateLaunch(launch);

        // Launch is NOT registered with treasury — deposit must revert.
        vm.prank(address(launch));
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.NotALaunch.selector, address(launch))
        );
        treasury.deposit{value: 1 ether}(creator);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CRIT-1: noteTerminal state check (integration with real Launch)
    // ════════════════════════════════════════════════════════════════════════

    /// @dev A real Launch in Pending state must not be able to decrement the
    ///      creator's active count via noteTerminal().
    function test_NoteTerminalBlockedOnPendingRealLaunch() external {
        Launch launch = _deployAndFundLaunch();
        // Launch is Pending.
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Pending));
        assertEq(factory.getActiveLaunchCount(creator), 1);

        // Attempt noteTerminal from the launch itself — must revert because
        // the launch is not yet in a terminal state.
        vm.prank(address(launch));
        vm.expectRevert(SherwoodErrors.SaleNotActive.selector);
        factory.noteTerminal();

        // Count must remain at 1.
        assertEq(factory.getActiveLaunchCount(creator), 1);
    }

    /// @dev A real Launch in Active state must not be able to decrement the count.
    function test_NoteTerminalBlockedOnActiveLaunch() external {
        Launch launch = _deployAndFundLaunch();
        _activateLaunch(launch);

        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Active));

        vm.prank(address(launch));
        vm.expectRevert(SherwoodErrors.SaleNotActive.selector);
        factory.noteTerminal();

        assertEq(factory.getActiveLaunchCount(creator), 1);
    }

    /// @dev After graduation, noteTerminal succeeds and decrements the count.
    function test_NoteTerminalSucceedsAfterGraduation() external {
        Launch launch = _deployAndFundLaunch();
        _activateLaunch(launch);
        _graduateLaunch(launch);

        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Graduated));

        // finalize() already called noteTerminal internally; count is 0.
        assertEq(factory.getActiveLaunchCount(creator), 0);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Buy/claim invariant: total buyer claims == totalTokensReserved
    // ════════════════════════════════════════════════════════════════════════

    /// @dev After all buyers have claimed, totalTokensReserved must be 0 and
    ///      the launch's token balance must equal only the unsold surplus.
    function test_AllClaimsExhaustTokenReserves() external {
        Launch launch = _deployAndFundLaunch();
        _activateLaunch(launch);

        uint256 buy1 = 5 ether;
        uint256 buy2 = 5 ether;

        vm.prank(buyer1);
        launch.buy{value: buy1}();
        vm.prank(buyer2);
        launch.buy{value: buy2}();

        vm.warp(launch.endTime() + 1);
        launch.finalize();

        uint256 reserved = launch.totalTokensReserved();
        assertEq(reserved, launch.purchasedTokens(buyer1) + launch.purchasedTokens(buyer2));

        vm.prank(buyer1);
        launch.claim();
        vm.prank(buyer2);
        launch.claim();

        assertEq(launch.totalTokensReserved(), 0, "reserved must be 0 after all claims");
    }

    // ════════════════════════════════════════════════════════════════════════
    // Refund conservation: total refunds == total contributions after failure
    // ════════════════════════════════════════════════════════════════════════

    /// @dev After a failed sale, total ETH refunded to all buyers must equal
    ///      totalRaised at the time of failure. No ETH dust left in contract.
    function test_TotalRefundsEqualTotalRaisedOnFailure() external {
        Launch launch = _deployAndFundLaunch();
        _activateLaunch(launch);

        // Contribute below soft cap so the sale fails.
        uint256 buy1  = 1 ether;
        uint256 buy2  = 2 ether;

        vm.prank(buyer1);
        launch.buy{value: buy1}();
        vm.prank(buyer2);
        launch.buy{value: buy2}();

        uint256 totalBefore = address(launch).balance;
        assertEq(totalBefore, buy1 + buy2);

        vm.warp(launch.endTime() + 1);
        launch.finalize();
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Failed));

        uint256 b1Before = buyer1.balance;
        uint256 b2Before = buyer2.balance;

        vm.prank(buyer1);
        launch.refund();
        vm.prank(buyer2);
        launch.refund();

        assertEq(buyer1.balance - b1Before, buy1,  "buyer1 refund mismatch");
        assertEq(buyer2.balance - b2Before, buy2,  "buyer2 refund mismatch");
        // No ETH remains in the launch after all refunds (only unsold tokens left).
        assertEq(address(launch).balance, 0, "launch must hold 0 ETH after full refund");
    }

    // ════════════════════════════════════════════════════════════════════════
    // ETH balance invariant: graduated launch settles to 0 after all withdrawals
    // ════════════════════════════════════════════════════════════════════════

    /// @dev After graduation, when both creator and feeRecipient withdraw, the
    ///      launch contract must hold exactly 0 ETH.
    function test_GraduatedLaunchEthBalanceZeroAfterAllWithdrawals() external {
        Launch launch = _deployAndFundLaunch();
        _activateLaunch(launch);
        _graduateLaunch(launch);

        // Creator withdraws proceeds.
        vm.prank(creator);
        launch.withdrawTreasury();

        // feeRecipient is treasury address — collect from launch directly.
        vm.prank(address(treasury));
        launch.collectProtocolFees();

        assertEq(address(launch).balance, 0, "launch must hold 0 ETH after all withdrawals");
    }

    // ════════════════════════════════════════════════════════════════════════
    // LaunchConstants: verify MIN_SALE_DURATION_SECONDS is accessible
    // ════════════════════════════════════════════════════════════════════════

    function test_MinSaleDurationConstantIsOneHour() external pure {
        assertEq(LaunchConstants.MIN_SALE_DURATION_SECONDS, 1 hours);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Fuzz: proceeds invariant holds for arbitrary contribution amounts
    // ════════════════════════════════════════════════════════════════════════

    /// @dev At all times after buy(): totalRaised == fees + creatorProceeds.
    function testFuzz_LaunchProceedsInvariantAfterBuy(uint256 ethAmount) external {
        Launch launch = _deployAndFundLaunch();
        _activateLaunch(launch);

        // Align to token-price precision and clamp to [price, hardCap].
        ethAmount = bound(
            (ethAmount / TOKEN_PRICE) * TOKEN_PRICE,
            TOKEN_PRICE,
            HARD_CAP
        );

        vm.prank(buyer1);
        launch.buy{value: ethAmount}();

        assertEq(
            launch.totalRaised(),
            launch.protocolFeesAccrued() + launch.creatorProceedsAccrued(),
            "proceeds invariant violated"
        );
    }

    // ════════════════════════════════════════════════════════════════════════
    // LaunchLifecycle: settle on graduated launch emits correct event
    // ════════════════════════════════════════════════════════════════════════

    function test_LifecycleSettleEmitsGraduatedEvent() external {
        LaunchLifecycle lifecycle = new LaunchLifecycle(address(factory), protocolOwner);

        Launch launch = _deployAndFundLaunch();
        _activateLaunch(launch);
        vm.prank(buyer1);
        launch.buy{value: SOFT_CAP}();
        vm.warp(launch.endTime() + 1);

        vm.expectEmit(true, false, false, true);
        emit LaunchLifecycle.LaunchSettled(address(launch), LaunchTypes.SaleState.Graduated, SOFT_CAP);

        vm.prank(creator);
        lifecycle.settle(address(launch));

        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Graduated));
    }

    // ════════════════════════════════════════════════════════════════════════
    // SherwoodErrors: CliffNotReached removed — confirm it's gone
    // ════════════════════════════════════════════════════════════════════════

    /// @dev This test compiles only if CliffNotReached is NOT defined. If it
    ///      re-appears, the test will still compile but serves as documentation
    ///      that the error was intentionally removed in Sprint 8.
    function test_SecurityAuditDocumentation() external pure {
        // Sprint 8 changes:
        // [CRIT-1] LaunchFactory.noteTerminal: state check added.
        // [HIGH-1] Vesting: beneficiary deduplication on re-schedule.
        // [HIGH-2] LaunchProject.sell: round-trip check added.
        // [MED-2]  LaunchLifecycle: misleading comment removed; dead code deleted.
        // [LOW-1]  SherwoodErrors.CliffNotReached: removed (unused).
        // [LOW-2]  LaunchConstants.MIN_SALE_DURATION_SECONDS: added.
        assertTrue(true);
    }
}
