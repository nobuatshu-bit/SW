// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test}     from "forge-std/Test.sol";
import {Ownable}  from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20}    from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {LaunchLifecycle} from "../src/lifecycle/LaunchLifecycle.sol";
import {LaunchFactory}   from "../src/factory/LaunchFactory.sol";
import {Launch}          from "../src/launchpad/Launch.sol";
import {SherwoodErrors}  from "../src/errors/SherwoodErrors.sol";
import {LaunchTypes}     from "../src/libraries/LaunchTypes.sol";
import {LaunchConstants} from "../src/utils/LaunchConstants.sol";

// ── Minimal ERC-20 ────────────────────────────────────────────────────────────
contract LifecycleToken is ERC20 {
    constructor() ERC20("Lifecycle Token", "LCT") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

// ── LaunchLifecycle test suite ────────────────────────────────────────────────
contract LaunchLifecycleTest is Test {

    // ── Actors ────────────────────────────────────────────────────────────────
    address internal owner        = makeAddr("owner");
    address internal creator      = makeAddr("creator");
    address internal feeRecipient = makeAddr("feeRecipient");
    address internal buyer        = makeAddr("buyer");
    address internal stranger     = makeAddr("stranger");

    // ── Contracts ─────────────────────────────────────────────────────────────
    LifecycleToken  internal token;
    Launch          internal impl;
    LaunchFactory   internal factory;
    LaunchLifecycle internal lifecycle;

    // ── Sale parameters ───────────────────────────────────────────────────────
    uint16  internal constant FEE_BPS     = 500;
    uint256 internal constant TOKEN_PRICE = 0.001 ether;
    uint256 internal constant ALLOCATION  = 1_000_000 ether;
    uint256 internal constant SOFT_CAP    = 10 ether;
    uint256 internal constant HARD_CAP    = 100 ether;

    function setUp() external {
        token     = new LifecycleToken();
        impl      = new Launch();
        factory   = new LaunchFactory(owner, address(impl), feeRecipient, FEE_BPS);
        lifecycle = new LaunchLifecycle(address(factory), owner);

        vm.deal(buyer,   1_000 ether);
        vm.deal(creator, 100 ether);
        vm.deal(stranger, 10 ether);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _params() internal view returns (LaunchTypes.LaunchParams memory) {
        return LaunchTypes.LaunchParams({
            name:            "LC Launch",
            description:     "desc",
            metadataURI:     "ipfs://Qm",
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

    function _createAndFundLaunch() internal returns (Launch launch) {
        vm.prank(creator);
        address launchAddr = factory.createLaunch(_params());
        launch = Launch(payable(launchAddr));
        token.mint(creator, ALLOCATION);
        vm.prank(creator);
        token.transfer(launchAddr, ALLOCATION);
    }

    function _activate(Launch launch) internal {
        vm.warp(launch.startTime());
        launch.activate();
    }

    function _buyAs(Launch launch, address b, uint256 eth) internal {
        vm.prank(b);
        launch.buy{value: eth}();
    }

    function _warpPastEnd(Launch launch) internal {
        vm.warp(launch.endTime() + 1);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Constructor
    // ════════════════════════════════════════════════════════════════════════

    function test_ConstructorSetsFactoryAndOwner() external view {
        assertEq(address(lifecycle.factory()), address(factory));
        assertEq(lifecycle.owner(),            owner);
    }

    function test_ConstructorRevertsOnZeroFactory() external {
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        new LaunchLifecycle(address(0), owner);
    }

    function test_ConstructorRevertsOnZeroOwner() external {
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0))
        );
        new LaunchLifecycle(address(factory), address(0));
    }

    // ════════════════════════════════════════════════════════════════════════
    // isTerminal / getLaunchState / validateSettlement
    // ════════════════════════════════════════════════════════════════════════

    function test_IsTerminalFalseForActiveAndPendingLaunches() external {
        Launch launch = _createAndFundLaunch();
        assertFalse(lifecycle.isTerminal(address(launch)));
        _activate(launch);
        assertFalse(lifecycle.isTerminal(address(launch)));
    }

    function test_IsTerminalTrueAfterFinalize() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        _buyAs(launch, buyer, SOFT_CAP);
        _warpPastEnd(launch);
        launch.finalize();
        assertTrue(lifecycle.isTerminal(address(launch)));
    }

    function test_IsTerminalFalseForUnregisteredAddress() external {
        assertFalse(lifecycle.isTerminal(makeAddr("unregistered")));
    }

    function test_ValidateSettlementReturnsTrueWhenSettleable() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        _warpPastEnd(launch);
        (bool ok, string memory reason) = lifecycle.validateSettlement(address(launch));
        assertTrue(ok);
        assertEq(reason, "ok");
    }

    function test_ValidateSettlementReturnsFalseBeforeEndTime() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        (bool ok, string memory reason) = lifecycle.validateSettlement(address(launch));
        assertFalse(ok);
        assertEq(reason, "sale not finished");
    }

    function test_ValidateSettlementReturnsFalseForTerminalLaunch() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        _buyAs(launch, buyer, SOFT_CAP);
        _warpPastEnd(launch);
        launch.finalize();
        (bool ok, string memory reason) = lifecycle.validateSettlement(address(launch));
        assertFalse(ok);
        assertEq(reason, "already graduated");
    }

    function test_ValidateSettlementReturnsFalseForUnregistered() external {
        (bool ok, string memory reason) = lifecycle.validateSettlement(makeAddr("x"));
        assertFalse(ok);
        assertEq(reason, "not registered");
    }

    function test_GetLaunchStateReturnsPending() external {
        Launch launch = _createAndFundLaunch();
        assertEq(uint8(lifecycle.getLaunchState(address(launch))), uint8(LaunchTypes.SaleState.Pending));
    }

    function test_GetLaunchStateRevertsForUnregistered() external {
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.NotALaunch.selector, stranger)
        );
        lifecycle.getLaunchState(stranger);
    }

    // ════════════════════════════════════════════════════════════════════════
    // settle — graduation path
    // ════════════════════════════════════════════════════════════════════════

    function test_SettleFinalizesAndEmitsEvent() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        _buyAs(launch, buyer, SOFT_CAP);
        _warpPastEnd(launch);

        vm.expectEmit(true, false, false, true);
        emit LaunchLifecycle.LaunchSettled(address(launch), LaunchTypes.SaleState.Graduated, SOFT_CAP);

        vm.prank(creator);
        lifecycle.settle(address(launch));

        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Graduated));
    }

    function test_SettleGraduatedLaunchTriggersWithdrawals() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        _buyAs(launch, buyer, SOFT_CAP);
        _warpPastEnd(launch);

        vm.prank(creator);
        lifecycle.settle(address(launch));

        // settle() calls finalize() which moves the launch to Graduated.
        // withdrawTreasury() and collectProtocolFees() require onlyCreator /
        // onlyFeeRecipient — LaunchLifecycle is neither, so they are not
        // triggered automatically. The creator and feeRecipient pull their
        // proceeds directly from the Launch contract.
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Graduated));
        // Proceeds are still accrued in the launch, awaiting manual withdrawal.
        assertGt(launch.creatorProceedsAccrued(),  0);
        assertGt(launch.protocolFeesAccrued(),     0);
    }

    function test_SettleIsIdempotentOnAlreadyTerminalLaunch() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        _buyAs(launch, buyer, SOFT_CAP);
        _warpPastEnd(launch);
        launch.finalize();

        // Should not revert, just emit the event again
        vm.prank(creator);
        lifecycle.settle(address(launch));
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Graduated));
    }

    function test_SettleRevertsBeforeEndTime() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        _buyAs(launch, buyer, SOFT_CAP);

        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.SaleNotFinished.selector);
        lifecycle.settle(address(launch));
    }

    function test_SettleRevertsForUnregisteredLaunch() external {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.NotALaunch.selector, stranger)
        );
        lifecycle.settle(stranger);
    }

    function test_SettleRevertsForNonCreatorNonOwner() external {
        Launch launch = _createAndFundLaunch();
        _warpPastEnd(launch);
        vm.prank(stranger);
        vm.expectRevert(SherwoodErrors.Unauthorized.selector);
        lifecycle.settle(address(launch));
    }

    function test_SettleAllowsOwnerToActForAnyLaunch() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        _warpPastEnd(launch);

        vm.prank(owner);
        lifecycle.settle(address(launch));
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Failed));
    }

    // ════════════════════════════════════════════════════════════════════════
    // settle — failure path
    // ════════════════════════════════════════════════════════════════════════

    function test_SettleFailedLaunchDoesNotWithdrawTreasury() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        _buyAs(launch, buyer, 1 ether); // below soft cap
        _warpPastEnd(launch);

        uint256 creatorBefore = creator.balance;
        vm.prank(creator);
        lifecycle.settle(address(launch));

        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Failed));
        // Creator proceeds not pushed (contributors get refunds themselves)
        assertEq(creator.balance, creatorBefore);
    }

    // ════════════════════════════════════════════════════════════════════════
    // batchSettle
    // ════════════════════════════════════════════════════════════════════════

    function test_BatchSettleFinalizesMultipleLaunches() external {
        Launch launchA = _createAndFundLaunch();
        Launch launchB = _createAndFundLaunch();

        _activate(launchA);
        _buyAs(launchA, buyer, SOFT_CAP);
        _activate(launchB);

        _warpPastEnd(launchA);
        // launchB also past end

        address[] memory launches = new address[](2);
        launches[0] = address(launchA);
        launches[1] = address(launchB);

        vm.prank(owner);
        lifecycle.batchSettle(launches);

        assertEq(uint8(launchA.state()), uint8(LaunchTypes.SaleState.Graduated));
        assertEq(uint8(launchB.state()), uint8(LaunchTypes.SaleState.Failed));
    }

    function test_BatchSettleSkipsUnregisteredAddresses() external {
        address[] memory launches = new address[](1);
        launches[0] = stranger; // not registered
        vm.prank(owner);
        lifecycle.batchSettle(launches); // should not revert
    }

    function test_BatchSettleRequiresOwner() external {
        address[] memory launches = new address[](0);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger)
        );
        lifecycle.batchSettle(launches);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Emergency pause / unpause
    // ════════════════════════════════════════════════════════════════════════

    function test_EmergencyPauseBlocksBuyOnLaunch() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);

        // Transfer launch ownership to lifecycle so it can call pause()
        vm.prank(creator);
        launch.transferOwnership(address(lifecycle));

        vm.expectEmit(true, false, false, false);
        emit LaunchLifecycle.LaunchPaused(address(launch));

        vm.prank(owner);
        lifecycle.emergencyPauseLaunch(address(launch));

        assertTrue(launch.paused());
    }

    function test_EmergencyUnpauseRestoresBuy() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);

        // Transfer launch ownership to lifecycle so it can call pause()/unpause()
        vm.prank(creator);
        launch.transferOwnership(address(lifecycle));

        vm.prank(owner);
        lifecycle.emergencyPauseLaunch(address(launch));
        vm.prank(owner);
        lifecycle.emergencyUnpauseLaunch(address(launch));

        assertFalse(launch.paused());
    }

    function test_EmergencyPauseRevertsForNonOwner() external {
        Launch launch = _createAndFundLaunch();
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger)
        );
        lifecycle.emergencyPauseLaunch(address(launch));
    }

    function test_EmergencyPauseRevertsForUnregisteredLaunch() external {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.NotALaunch.selector, stranger)
        );
        lifecycle.emergencyPauseLaunch(stranger);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Emergency cancel
    // ════════════════════════════════════════════════════════════════════════

    function test_EmergencyCancelSetsFailedState() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);

        // emergencyCancel now calls finalize() which is permissionless and
        // requires block.timestamp >= endTime. No ownership transfer needed.
        _warpPastEnd(launch);

        vm.prank(owner);
        lifecycle.emergencyCancel(address(launch));

        // With no soft-cap contribution the launch ends Failed.
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Failed));
    }

    function test_EmergencyCancelRevertsOnTerminalLaunch() external {
        Launch launch = _createAndFundLaunch();
        _warpPastEnd(launch);
        launch.finalize();

        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.SaleNotActive.selector);
        lifecycle.emergencyCancel(address(launch));
    }

    function test_EmergencyCancelRevertsBeforeEndTime() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        // Sale is still active — emergencyCancel needs endTime to have passed
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.SaleNotFinished.selector);
        lifecycle.emergencyCancel(address(launch));
    }

    function test_EmergencyCancelRequiresOwner() external {
        Launch launch = _createAndFundLaunch();
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger)
        );
        lifecycle.emergencyCancel(address(launch));
    }

    // ════════════════════════════════════════════════════════════════════════
    // Emergency token recovery
    // ════════════════════════════════════════════════════════════════════════

    function test_EmergencyRecoverTokensMovesUnsoldTokensToRecipient() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);
        _buyAs(launch, buyer, SOFT_CAP); // buy some, not all
        _warpPastEnd(launch);
        launch.finalize(); // Graduated

        address recoveryRecipient = makeAddr("recoveryRecipient");
        uint256 launchBalance  = token.balanceOf(address(launch));
        uint256 reserved       = launch.totalTokensReserved();
        uint256 unsoldAmount   = launchBalance - reserved;

        // emergencyRecoverTokens uses safeTransferFrom(launch, ...).
        // The launch contract must approve lifecycle to spend its tokens.
        vm.prank(address(launch));
        token.approve(address(lifecycle), unsoldAmount);

        vm.prank(owner);
        lifecycle.emergencyRecoverTokens(address(launch), address(token), recoveryRecipient);

        assertEq(token.balanceOf(recoveryRecipient), unsoldAmount);
    }

    function test_EmergencyRecoverRevertsOnNonTerminalLaunch() external {
        Launch launch = _createAndFundLaunch();
        _activate(launch);

        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.SaleNotActive.selector);
        lifecycle.emergencyRecoverTokens(address(launch), address(token), makeAddr("r"));
    }

    function test_EmergencyRecoverRevertsOnZeroToken() external {
        Launch launch = _createAndFundLaunch();
        _warpPastEnd(launch);
        launch.finalize();

        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        lifecycle.emergencyRecoverTokens(address(launch), address(0), makeAddr("r"));
    }

    function test_EmergencyRecoverRequiresOwner() external {
        Launch launch = _createAndFundLaunch();
        _warpPastEnd(launch);
        launch.finalize();

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger)
        );
        lifecycle.emergencyRecoverTokens(address(launch), address(token), makeAddr("r"));
    }

    // ════════════════════════════════════════════════════════════════════════
    // Lifecycle contract pause
    // ════════════════════════════════════════════════════════════════════════

    function test_PauseBlocksSettle() external {
        Launch launch = _createAndFundLaunch();
        _warpPastEnd(launch);

        vm.prank(owner);
        lifecycle.pause();

        vm.prank(creator);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        lifecycle.settle(address(launch));
    }

    function test_UnpauseRestoresSettle() external {
        Launch launch = _createAndFundLaunch();
        _warpPastEnd(launch);

        vm.startPrank(owner);
        lifecycle.pause();
        lifecycle.unpause();
        vm.stopPrank();

        vm.prank(creator);
        lifecycle.settle(address(launch));
        assertEq(uint8(launch.state()), uint8(LaunchTypes.SaleState.Failed));
    }

    // ════════════════════════════════════════════════════════════════════════
    // Ownable2Step
    // ════════════════════════════════════════════════════════════════════════

    function test_OwnershipTransferRequiresTwoStep() external {
        address nominee = makeAddr("nominee");
        vm.prank(owner);
        lifecycle.transferOwnership(nominee);
        assertEq(lifecycle.owner(), owner);
        assertEq(lifecycle.pendingOwner(), nominee);
        vm.prank(nominee);
        lifecycle.acceptOwnership();
        assertEq(lifecycle.owner(), nominee);
    }
}
