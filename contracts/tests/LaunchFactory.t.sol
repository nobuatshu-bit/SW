// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {LaunchFactory}   from "../src/factory/LaunchFactory.sol";
import {ILaunch}         from "../src/interfaces/ILaunch.sol";
import {ILaunchFactory}  from "../src/interfaces/ILaunchFactory.sol";
import {SherwoodErrors}  from "../src/errors/SherwoodErrors.sol";
import {LaunchTypes}     from "../src/libraries/LaunchTypes.sol";
import {LaunchConstants} from "../src/utils/LaunchConstants.sol";

// ── Minimal Launch stub ────────────────────────────────────────────────────────
// Satisfies ILaunch.initialize without implementing any sale logic.
// Used as both the implementation template AND as a direct clone target in tests.

contract MockLaunch is ILaunch {
    address public factory_;
    address public creator_;
    address public token_;
    address public feeRecipient_;
    uint16  public feeBps_;
    bool    public initialized;

    function initialize(
        address factory__,
        address creator__,
        address token__,
        address feeRecipient__,
        uint16  protocolFeeBps,
        LaunchTypes.LaunchParams calldata
    ) external override {
        require(!initialized, "already initialized");
        factory_      = factory__;
        creator_      = creator__;
        token_        = token__;
        feeRecipient_ = feeRecipient__;
        feeBps_       = protocolFeeBps;
        initialized   = true;
    }
}

// ── Test contract ──────────────────────────────────────────────────────────────

contract LaunchFactoryTest is Test {
    // ── Actors ────────────────────────────────────────────────────────────────
    address internal owner          = makeAddr("owner");
    address internal creator        = makeAddr("creator");
    address internal creatorB       = makeAddr("creatorB");
    address internal feeRecipient   = makeAddr("feeRecipient");
    address internal newRecipient   = makeAddr("newRecipient");
    address internal token          = makeAddr("token");

    // ── Contracts ────────────────────────────────────────────────────────────
    MockLaunch   internal implementation;
    LaunchFactory internal factory;

    uint16 internal constant INITIAL_FEE_BPS = 250; // 2.5 %

    // ── Setup ─────────────────────────────────────────────────────────────────

    function setUp() external {
        implementation = new MockLaunch();
        factory = new LaunchFactory(owner, address(implementation), feeRecipient, INITIAL_FEE_BPS);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _params() internal view returns (LaunchTypes.LaunchParams memory) {
        return LaunchTypes.LaunchParams({
            name:           "Test Launch",
            description:    "A test launch",
            metadataURI:    "ipfs://QmTest",
            token:          token,
            tokenPrice:     0.01 ether,
            tokenAllocation: 1_000_000 ether,
            softCap:        1 ether,
            hardCap:        100 ether,
            startTime:      uint64(block.timestamp + 1 hours),
            endTime:        uint64(block.timestamp + 2 hours)
        });
    }

    /// @dev Creates a launch as `creator` and returns the deployed clone address.
    function _createLaunch() internal returns (address launch) {
        vm.prank(creator);
        launch = factory.createLaunch(_params());
    }

    // ════════════════════════════════════════════════════════════════════════
    // Construction
    // ════════════════════════════════════════════════════════════════════════

    function test_ConstructorStoresInitialConfiguration() external view {
        assertEq(factory.owner(),                owner);
        assertEq(factory.feeRecipient(),         feeRecipient);
        assertEq(factory.protocolFeeBps(),       INITIAL_FEE_BPS);
        assertEq(factory.launchImplementation(), address(implementation));
        assertEq(factory.launchCount(),          0);
    }

    function test_ConstructorRevertsOnZeroOwner() external {
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0))
        );
        new LaunchFactory(address(0), address(implementation), feeRecipient, INITIAL_FEE_BPS);
    }

    function test_ConstructorRevertsOnZeroFeeRecipient() external {
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        new LaunchFactory(owner, address(implementation), address(0), INITIAL_FEE_BPS);
    }

    function test_ConstructorRevertsOnZeroImplementation() external {
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        new LaunchFactory(owner, address(0), feeRecipient, INITIAL_FEE_BPS);
    }

    function test_ConstructorRevertsOnEOAImplementation() external {
        address eoa = makeAddr("eoa");
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        new LaunchFactory(owner, eoa, feeRecipient, INITIAL_FEE_BPS);
    }

    function test_ConstructorRevertsOnExcessiveFee() external {
        uint16 overLimit = LaunchConstants.MAX_PROTOCOL_FEE_BPS + 1;
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.InvalidFeeBps.selector, overLimit)
        );
        new LaunchFactory(owner, address(implementation), feeRecipient, overLimit);
    }

    // ════════════════════════════════════════════════════════════════════════
    // createLaunch — success path
    // ════════════════════════════════════════════════════════════════════════

    function test_CreateLaunchDeploysInitialisedCloneAndRegistersRecord() external {
        vm.expectEmit(false, true, true, false);
        emit LaunchFactory.LaunchCreated(address(0), creator, token, 0, 0);

        address launch = _createLaunch();

        // Registry
        assertEq(factory.launchCount(), 1);
        assertEq(factory.launchAt(0),   launch);

        // Clone was initialised
        MockLaunch clone = MockLaunch(launch);
        assertTrue(clone.initialized());
        assertEq(clone.factory_(),      address(factory));
        assertEq(clone.creator_(),      creator);
        assertEq(clone.token_(),        token);
        assertEq(clone.feeRecipient_(), feeRecipient);
        assertEq(clone.feeBps_(),       INITIAL_FEE_BPS);
    }

    function test_CreateLaunchStoresImmutableRecord() external {
        address launch = _createLaunch();

        LaunchTypes.LaunchRecord memory rec = factory.getLaunchRecord(launch);
        LaunchTypes.LaunchParams  memory p  = _params();

        assertEq(rec.launch,          launch);
        assertEq(rec.creator,         creator);
        assertEq(rec.token,           token);
        assertEq(rec.protocolFeeBps,  INITIAL_FEE_BPS);
        assertEq(rec.tokenPrice,      p.tokenPrice);
        assertEq(rec.tokenAllocation, p.tokenAllocation);
        assertEq(rec.softCap,         p.softCap);
        assertEq(rec.hardCap,         p.hardCap);
        assertEq(rec.startTime,       p.startTime);
        assertEq(rec.endTime,         p.endTime);
        assertEq(rec.createdAt,       uint64(block.timestamp));
    }

    function test_CreateLaunchRegistersToCreatorList() external {
        address launch = _createLaunch();

        address[] memory byCreator = factory.getLaunchesByCreator(creator);
        assertEq(byCreator.length, 1);
        assertEq(byCreator[0],     launch);
    }

    function test_CreateLaunchIncrementsActiveCount() external {
        assertEq(factory.getActiveLaunchCount(creator), 0);
        _createLaunch();
        assertEq(factory.getActiveLaunchCount(creator), 1);
    }

    function test_CreateLaunchMarksAddressAsRegistered() external {
        address launch = _createLaunch();
        assertTrue(factory.isRegistered(launch));
        assertFalse(factory.isRegistered(makeAddr("unknown")));
    }

    function test_CreateLaunchSnapshotsCurrentFeeAtCreationTime() external {
        // Change fee after first launch
        address launchA = _createLaunch();

        vm.prank(owner);
        factory.setProtocolFee(500);

        vm.prank(creator);
        address launchB = factory.createLaunch(_params());

        // launchA record must still carry 250, launchB must carry 500
        assertEq(factory.getLaunchRecord(launchA).protocolFeeBps, 250);
        assertEq(factory.getLaunchRecord(launchB).protocolFeeBps, 500);

        // Clone was initialised with the fee at the time of creation
        assertEq(MockLaunch(launchA).feeBps_(), 250);
        assertEq(MockLaunch(launchB).feeBps_(), 500);
    }

    function test_MultipleLaunchesIndexCorrectly() external {
        vm.startPrank(creator);
        address a = factory.createLaunch(_params());
        address b = factory.createLaunch(_params());
        address c = factory.createLaunch(_params());
        vm.stopPrank();

        assertEq(factory.launchCount(), 3);
        assertEq(factory.launchAt(0), a);
        assertEq(factory.launchAt(1), b);
        assertEq(factory.launchAt(2), c);

        address[] memory byCreator = factory.getLaunchesByCreator(creator);
        assertEq(byCreator.length, 3);
    }

    function test_MultipleLaunchesFromDifferentCreatorsAreIsolated() external {
        vm.prank(creator);
        factory.createLaunch(_params());

        vm.prank(creatorB);
        factory.createLaunch(_params());

        assertEq(factory.getLaunchesByCreator(creator).length,  1);
        assertEq(factory.getLaunchesByCreator(creatorB).length, 1);
        assertEq(factory.getActiveLaunchCount(creator),         1);
        assertEq(factory.getActiveLaunchCount(creatorB),        1);
    }

    // ════════════════════════════════════════════════════════════════════════
    // createLaunch — validation failures
    // ════════════════════════════════════════════════════════════════════════

    function test_CreateLaunchRevertsOnZeroToken() external {
        LaunchTypes.LaunchParams memory p = _params();
        p.token = address(0);

        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        factory.createLaunch(p);
    }

    function test_CreateLaunchRevertsOnEmptyName() external {
        LaunchTypes.LaunchParams memory p = _params();
        p.name = "";

        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.InvalidLaunchConfiguration.selector);
        factory.createLaunch(p);
    }

    function test_CreateLaunchRevertsOnZeroTokenPrice() external {
        LaunchTypes.LaunchParams memory p = _params();
        p.tokenPrice = 0;

        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.InvalidTokenAmount.selector);
        factory.createLaunch(p);
    }

    function test_CreateLaunchRevertsOnZeroTokenAllocation() external {
        LaunchTypes.LaunchParams memory p = _params();
        p.tokenAllocation = 0;

        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.InvalidTokenAmount.selector);
        factory.createLaunch(p);
    }

    function test_CreateLaunchRevertsOnZeroSoftCap() external {
        LaunchTypes.LaunchParams memory p = _params();
        p.softCap = 0;

        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.InvalidLaunchConfiguration.selector);
        factory.createLaunch(p);
    }

    function test_CreateLaunchRevertsWhenHardCapBelowSoftCap() external {
        LaunchTypes.LaunchParams memory p = _params();
        p.hardCap = p.softCap - 1;

        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.InvalidLaunchConfiguration.selector);
        factory.createLaunch(p);
    }

    function test_CreateLaunchRevertsOnStartTimeInPast() external {
        LaunchTypes.LaunchParams memory p = _params();
        p.startTime = uint64(block.timestamp - 1);

        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.SaleNotStarted.selector);
        factory.createLaunch(p);
    }

    function test_CreateLaunchRevertsWhenEndTimeNotAfterStartTime() external {
        LaunchTypes.LaunchParams memory p = _params();
        p.endTime = p.startTime; // equal, not strictly after

        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.InvalidLaunchDuration.selector);
        factory.createLaunch(p);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Active launch cap
    // ════════════════════════════════════════════════════════════════════════

    function test_CreateLaunchEnforcesPerCreatorActiveCap() external {
        uint256 limit = LaunchConstants.MAX_LAUNCHES_PER_CREATOR;

        vm.startPrank(creator);
        for (uint256 i = 0; i < limit; i++) {
            factory.createLaunch(_params());
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                SherwoodErrors.TooManyActiveLaunches.selector,
                creator,
                limit
            )
        );
        factory.createLaunch(_params());
        vm.stopPrank();
    }

    function test_NoteTerminalDecrementsActiveCountAndAllowsNewLaunch() external {
        uint256 limit = LaunchConstants.MAX_LAUNCHES_PER_CREATOR;

        vm.startPrank(creator);
        for (uint256 i = 0; i < limit; i++) {
            factory.createLaunch(_params());
        }
        vm.stopPrank();

        assertEq(factory.getActiveLaunchCount(creator), limit);

        // Simulate the first launch reaching a terminal state.
        address firstLaunch = factory.launchAt(0);
        vm.prank(firstLaunch);
        factory.noteTerminal();

        assertEq(factory.getActiveLaunchCount(creator), limit - 1);

        // Creator can now create one more.
        vm.prank(creator);
        factory.createLaunch(_params());
        assertEq(factory.getActiveLaunchCount(creator), limit);
    }

    function test_NoteTerminalRevertsForUnregisteredCaller() external {
        address impostor = makeAddr("impostor");
        vm.prank(impostor);
        vm.expectRevert(SherwoodErrors.Unauthorized.selector);
        factory.noteTerminal();
    }

    function test_NoteTerminalEmitsEvent() external {
        address launch = _createLaunch();

        vm.expectEmit(true, true, false, false);
        emit LaunchFactory.LaunchTerminated(launch, creator);

        vm.prank(launch);
        factory.noteTerminal();
    }

    function test_NoteTerminalIsIdempotentBelowZero() external {
        address launch = _createLaunch();

        // Call twice — second call must not underflow (counter saturates at 0).
        vm.prank(launch);
        factory.noteTerminal();
        assertEq(factory.getActiveLaunchCount(creator), 0);

        vm.prank(launch);
        factory.noteTerminal(); // should not revert
        assertEq(factory.getActiveLaunchCount(creator), 0);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Pause / Unpause
    // ════════════════════════════════════════════════════════════════════════

    function test_PauseBlocksLaunchCreation() external {
        vm.prank(owner);
        factory.pause();
        assertTrue(factory.paused());

        vm.prank(creator);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        factory.createLaunch(_params());
    }

    function test_UnpauseRestoresLaunchCreation() external {
        vm.startPrank(owner);
        factory.pause();
        factory.unpause();
        vm.stopPrank();

        assertFalse(factory.paused());

        vm.prank(creator);
        factory.createLaunch(_params());
        assertEq(factory.launchCount(), 1);
    }

    function test_PauseRequiresOwner() external {
        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, creator)
        );
        factory.pause();
    }

    function test_UnpauseRequiresOwner() external {
        vm.prank(owner);
        factory.pause();

        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, creator)
        );
        factory.unpause();
    }

    // ════════════════════════════════════════════════════════════════════════
    // setProtocolFee
    // ════════════════════════════════════════════════════════════════════════

    function test_SetProtocolFeeUpdatesValueAndEmitsEvent() external {
        vm.expectEmit(true, true, false, false);
        emit LaunchFactory.ProtocolFeeUpdated(INITIAL_FEE_BPS, 500);

        vm.prank(owner);
        factory.setProtocolFee(500);
        assertEq(factory.protocolFeeBps(), 500);
    }

    function test_SetProtocolFeeAcceptsZero() external {
        vm.prank(owner);
        factory.setProtocolFee(0);
        assertEq(factory.protocolFeeBps(), 0);
    }

    function test_SetProtocolFeeAcceptsMaximum() external {
        vm.prank(owner);
        factory.setProtocolFee(LaunchConstants.MAX_PROTOCOL_FEE_BPS);
        assertEq(factory.protocolFeeBps(), LaunchConstants.MAX_PROTOCOL_FEE_BPS);
    }

    function test_SetProtocolFeeRevertsAboveMaximum() external {
        uint16 over = LaunchConstants.MAX_PROTOCOL_FEE_BPS + 1;
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.InvalidFeeBps.selector, over)
        );
        factory.setProtocolFee(over);
    }

    function test_SetProtocolFeeRequiresOwner() external {
        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, creator)
        );
        factory.setProtocolFee(100);
    }

    // ════════════════════════════════════════════════════════════════════════
    // setFeeRecipient
    // ════════════════════════════════════════════════════════════════════════

    function test_SetFeeRecipientUpdatesValueAndEmitsEvent() external {
        vm.expectEmit(true, true, false, false);
        emit LaunchFactory.FeeRecipientUpdated(feeRecipient, newRecipient);

        vm.prank(owner);
        factory.setFeeRecipient(newRecipient);
        assertEq(factory.feeRecipient(), newRecipient);
    }

    function test_SetFeeRecipientRevertsOnZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        factory.setFeeRecipient(address(0));
    }

    function test_SetFeeRecipientRequiresOwner() external {
        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, creator)
        );
        factory.setFeeRecipient(newRecipient);
    }

    // ════════════════════════════════════════════════════════════════════════
    // setLaunchImplementation
    // ════════════════════════════════════════════════════════════════════════

    function test_SetLaunchImplementationUpdatesValueAndEmitsEvent() external {
        MockLaunch newImpl = new MockLaunch();

        vm.expectEmit(true, true, false, false);
        emit LaunchFactory.LaunchImplementationUpdated(address(implementation), address(newImpl));

        vm.prank(owner);
        factory.setLaunchImplementation(address(newImpl));
        assertEq(factory.launchImplementation(), address(newImpl));
    }

    function test_SetLaunchImplementationAffectsOnlyFutureLaunches() external {
        // Create a launch with the old implementation
        address oldLaunch = _createLaunch();

        // Swap implementation
        MockLaunch newImpl = new MockLaunch();
        vm.prank(owner);
        factory.setLaunchImplementation(address(newImpl));

        // Create a launch with the new implementation
        vm.prank(creator);
        address newLaunch = factory.createLaunch(_params());

        // Both launches are functional independent clones
        assertTrue(MockLaunch(oldLaunch).initialized());
        assertTrue(MockLaunch(newLaunch).initialized());
        assertTrue(oldLaunch != newLaunch);
    }

    function test_SetLaunchImplementationRevertsOnZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        factory.setLaunchImplementation(address(0));
    }

    function test_SetLaunchImplementationRevertsOnEOA() external {
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        factory.setLaunchImplementation(makeAddr("eoa"));
    }

    function test_SetLaunchImplementationRequiresOwner() external {
        MockLaunch newImpl = new MockLaunch();
        vm.prank(creator);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, creator)
        );
        factory.setLaunchImplementation(address(newImpl));
    }

    // ════════════════════════════════════════════════════════════════════════
    // Ownable2Step
    // ════════════════════════════════════════════════════════════════════════

    function test_OwnershipTransferRequiresTwoStep() external {
        address nominee = makeAddr("nominee");

        vm.prank(owner);
        factory.transferOwnership(nominee);

        // Pending transfer — old owner still in control
        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), nominee);

        // Nominee accepts
        vm.prank(nominee);
        factory.acceptOwnership();
        assertEq(factory.owner(), nominee);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Interface conformance
    // ════════════════════════════════════════════════════════════════════════

    function test_ConformsToILaunchFactoryInterface() external view {
        // Verifies the contract satisfies the interface at compile time.
        ILaunchFactory iface = ILaunchFactory(address(factory));
        assertEq(iface.protocolFeeBps(), INITIAL_FEE_BPS);
        assertEq(iface.feeRecipient(),   feeRecipient);
        assertEq(iface.launchCount(),    0);
    }
}
