// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test}     from "forge-std/Test.sol";
import {Ownable}  from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {Treasury}        from "../src/treasury/Treasury.sol";
import {SherwoodErrors}  from "../src/errors/SherwoodErrors.sol";
import {LaunchConstants} from "../src/utils/LaunchConstants.sol";

contract TreasuryTest is Test {

    // ── Actors ────────────────────────────────────────────────────────────────
    address internal owner        = makeAddr("owner");
    address internal recipientA   = makeAddr("recipientA");
    address internal recipientB   = makeAddr("recipientB");
    address internal sender1      = makeAddr("sender1");
    address internal sender2      = makeAddr("sender2");
    address internal stranger     = makeAddr("stranger");
    address internal creator      = makeAddr("creator");

    Treasury internal treasury;

    function setUp() external {
        treasury = new Treasury(owner);
        vm.deal(sender1, 1_000 ether);
        vm.deal(sender2, 1_000 ether);
        vm.deal(stranger, 100 ether);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _register(address sender) internal {
        vm.prank(owner);
        treasury.setSenderRegistration(sender, true);
    }

    function _splitAB(uint16 aBps, uint16 bBps)
        internal
        view
        returns (Treasury.FeeSplitEntry[] memory split)
    {
        split = new Treasury.FeeSplitEntry[](2);
        split[0] = Treasury.FeeSplitEntry(recipientA, aBps);
        split[1] = Treasury.FeeSplitEntry(recipientB, bBps);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Constructor
    // ════════════════════════════════════════════════════════════════════════

    function test_ConstructorSetsOwner() external view {
        assertEq(treasury.owner(), owner);
    }

    function test_ConstructorRevertsOnZeroOwner() external {
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0))
        );
        new Treasury(address(0));
    }

    // ════════════════════════════════════════════════════════════════════════
    // Sender registration
    // ════════════════════════════════════════════════════════════════════════

    function test_RegisterSenderSetsFlagAndEmitsEvent() external {
        vm.expectEmit(true, false, false, true);
        emit Treasury.SenderRegistrationUpdated(sender1, true);
        _register(sender1);
        assertTrue(treasury.isRegisteredSender(sender1));
    }

    function test_DeregisterSenderClearsFlagAndEmitsEvent() external {
        _register(sender1);
        vm.expectEmit(true, false, false, true);
        emit Treasury.SenderRegistrationUpdated(sender1, false);
        vm.prank(owner);
        treasury.setSenderRegistration(sender1, false);
        assertFalse(treasury.isRegisteredSender(sender1));
    }

    function test_RegisterSenderRevertsOnZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        treasury.setSenderRegistration(address(0), true);
    }

    function test_RegisterSenderRequiresOwner() external {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger)
        );
        treasury.setSenderRegistration(sender1, true);
    }

    function test_RegisterSendersBulkRegistersAll() external {
        address[] memory senders = new address[](2);
        senders[0] = sender1;
        senders[1] = sender2;
        vm.prank(owner);
        treasury.registerSenders(senders);
        assertTrue(treasury.isRegisteredSender(sender1));
        assertTrue(treasury.isRegisteredSender(sender2));
    }

    // ════════════════════════════════════════════════════════════════════════
    // setFeeSplit
    // ════════════════════════════════════════════════════════════════════════

    function test_SetFeeSplitStoresSplitAndEmitsEvent() external {
        Treasury.FeeSplitEntry[] memory split = _splitAB(6_000, 4_000);
        vm.expectEmit(false, false, false, false);
        emit Treasury.FeeSplitUpdated(split);
        vm.prank(owner);
        treasury.setFeeSplit(split);

        Treasury.FeeSplitEntry[] memory stored = treasury.getFeeSplit();
        assertEq(stored.length, 2);
        assertEq(stored[0].recipient, recipientA);
        assertEq(stored[0].shareBps,  6_000);
        assertEq(stored[1].recipient, recipientB);
        assertEq(stored[1].shareBps,  4_000);
    }

    function test_SetFeeSplitAllowsEmptyArray() external {
        Treasury.FeeSplitEntry[] memory split = new Treasury.FeeSplitEntry[](0);
        vm.prank(owner);
        treasury.setFeeSplit(split);
        assertEq(treasury.getFeeSplit().length, 0);
    }

    function test_SetFeeSplitRevertsWhenSharesDontSum() external {
        Treasury.FeeSplitEntry[] memory split = _splitAB(5_000, 4_000); // 9000 != 10000
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.RecipientSharesMismatch.selector);
        treasury.setFeeSplit(split);
    }

    function test_SetFeeSplitRevertsOnZeroRecipient() external {
        Treasury.FeeSplitEntry[] memory split = new Treasury.FeeSplitEntry[](1);
        split[0] = Treasury.FeeSplitEntry(address(0), 10_000);
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        treasury.setFeeSplit(split);
    }

    function test_SetFeeSplitRevertsOnZeroShare() external {
        Treasury.FeeSplitEntry[] memory split = new Treasury.FeeSplitEntry[](2);
        split[0] = Treasury.FeeSplitEntry(recipientA, 0);
        split[1] = Treasury.FeeSplitEntry(recipientB, 10_000);
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidAllocation.selector);
        treasury.setFeeSplit(split);
    }

    function test_SetFeeSplitRevertsAboveMaxRecipients() external {
        Treasury.FeeSplitEntry[] memory split = new Treasury.FeeSplitEntry[](11);
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidRecipientCount.selector);
        treasury.setFeeSplit(split);
    }

    function test_SetFeeSplitRequiresOwner() external {
        Treasury.FeeSplitEntry[] memory split = _splitAB(5_000, 5_000);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger)
        );
        treasury.setFeeSplit(split);
    }

    // ════════════════════════════════════════════════════════════════════════
    // deposit — no split (owner gets all)
    // ════════════════════════════════════════════════════════════════════════

    function test_DepositWithNoSplitCreditsOwner() external {
        _register(sender1);
        vm.prank(sender1);
        treasury.deposit{value: 1 ether}(creator);
        assertEq(treasury.allocations(owner), 1 ether);
    }

    function test_DepositEmitsEvent() external {
  	_register(sender1);

vm.expectEmit(true, true, false, true);
emit Treasury.Deposited(sender1, creator, 1 ether);

vm.prank(sender1);
treasury.deposit{value: 1 ether}(creator);
  }

    function test_DepositRevertsFromUnregisteredSender() external {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.NotALaunch.selector, stranger)
        );
        treasury.deposit{value: 1 ether}(creator);
    }

    function test_DepositRevertsOnZeroValue() external {
        _register(sender1);
        vm.prank(sender1);
        vm.expectRevert(SherwoodErrors.InvalidPaymentAmount.selector);
        treasury.deposit{value: 0}(creator);
    }

    // ════════════════════════════════════════════════════════════════════════
    // deposit — with split
    // ════════════════════════════════════════════════════════════════════════

    function test_DepositDistributesAccordingToSplit() external {
        _register(sender1);
        Treasury.FeeSplitEntry[] memory split = _splitAB(6_000, 4_000);
        vm.prank(owner);
        treasury.setFeeSplit(split);

        vm.prank(sender1);
        treasury.deposit{value: 10 ether}(creator);

        assertEq(treasury.allocations(recipientA), 6 ether);
        assertEq(treasury.allocations(recipientB), 4 ether);
    }

    function test_DepositHandlesRoundingDustOnLastRecipient() external {
        _register(sender1);
        // Three-way split: 33.33% each (sums to 9999 bps, not exact)
        // Instead use 3334 + 3333 + 3333 = 10000
        Treasury.FeeSplitEntry[] memory split = new Treasury.FeeSplitEntry[](3);
        address rC = makeAddr("recipientC");
        split[0] = Treasury.FeeSplitEntry(recipientA, 3_334);
        split[1] = Treasury.FeeSplitEntry(recipientB, 3_333);
        split[2] = Treasury.FeeSplitEntry(rC,         3_333);
        vm.prank(owner);
        treasury.setFeeSplit(split);

        vm.prank(sender1);
        treasury.deposit{value: 1 ether}(creator);

        uint256 total = treasury.allocations(recipientA) +
                        treasury.allocations(recipientB) +
                        treasury.allocations(rC);
        assertEq(total, 1 ether); // no dust lost
    }

    function test_DepositAccumulatesCorrectlyAcrossMultipleDeposits() external {
        _register(sender1);
        _register(sender2);
        Treasury.FeeSplitEntry[] memory split = _splitAB(5_000, 5_000);
        vm.prank(owner);
        treasury.setFeeSplit(split);

        vm.prank(sender1);
        treasury.deposit{value: 2 ether}(creator);

        vm.prank(sender2);
        treasury.deposit{value: 4 ether}(creator);

        assertEq(treasury.allocations(recipientA), 3 ether);
        assertEq(treasury.allocations(recipientB), 3 ether);
    }

    // ════════════════════════════════════════════════════════════════════════
    // withdraw
    // ════════════════════════════════════════════════════════════════════════

    function test_WithdrawTransfersFullAllocationAndZeroesBalance() external {
        _register(sender1);
        Treasury.FeeSplitEntry[] memory split = _splitAB(10_000, 0);
        split = new Treasury.FeeSplitEntry[](1);
        split[0] = Treasury.FeeSplitEntry(recipientA, 10_000);
        vm.prank(owner);
        treasury.setFeeSplit(split);

        vm.prank(sender1);
        treasury.deposit{value: 5 ether}(creator);

        uint256 before = recipientA.balance;
        vm.expectEmit(true, false, false, true);
        emit Treasury.Withdrawn(recipientA, 5 ether);
        vm.prank(recipientA);
        treasury.withdraw();

        assertEq(recipientA.balance, before + 5 ether);
        assertEq(treasury.allocations(recipientA), 0);
    }

    function test_WithdrawRevertsOnZeroBalance() external {
        vm.prank(stranger);
        vm.expectRevert(SherwoodErrors.NoWithdrawableBalance.selector);
        treasury.withdraw();
    }

    function test_WithdrawPartialTransfersExactAmountAndLeavesRemainder() external {
        _register(sender1);
        Treasury.FeeSplitEntry[] memory split = new Treasury.FeeSplitEntry[](1);
        split[0] = Treasury.FeeSplitEntry(recipientA, 10_000);
        vm.prank(owner);
        treasury.setFeeSplit(split);

        vm.prank(sender1);
        treasury.deposit{value: 10 ether}(creator);

        vm.prank(recipientA);
        treasury.withdrawPartial(3 ether);

        assertEq(treasury.allocations(recipientA), 7 ether);
        assertEq(recipientA.balance,                3 ether);
    }

    function test_WithdrawPartialRevertsOnZeroAmount() external {
        _register(sender1);
        vm.prank(sender1);
        treasury.deposit{value: 1 ether}(creator);
        vm.prank(owner);
        treasury.withdraw();
        // Now try zero partial
        vm.prank(stranger);
        vm.expectRevert(SherwoodErrors.InvalidPaymentAmount.selector);
        treasury.withdrawPartial(0);
    }

    function test_WithdrawPartialRevertsWhenExceedingAllocation() external {
        _register(sender1);
        Treasury.FeeSplitEntry[] memory split = new Treasury.FeeSplitEntry[](1);
        split[0] = Treasury.FeeSplitEntry(recipientA, 10_000);
        vm.prank(owner);
        treasury.setFeeSplit(split);
        vm.prank(sender1);
        treasury.deposit{value: 2 ether}(creator);

        vm.prank(recipientA);
        vm.expectRevert(SherwoodErrors.NoWithdrawableBalance.selector);
        treasury.withdrawPartial(3 ether);
    }

    // ════════════════════════════════════════════════════════════════════════
    // receive() — plain ETH
    // ════════════════════════════════════════════════════════════════════════

    function test_ReceiveCreditOwnerAllocation() external {
        vm.deal(stranger, 5 ether);
        // Use call instead of transfer — transfer only forwards 2300 gas which
        // is insufficient for the SSTORE in receive(). call forwards all gas.
        vm.prank(stranger);
        (bool ok,) = payable(address(treasury)).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(treasury.allocations(owner), 1 ether);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Pause / Unpause
    // ════════════════════════════════════════════════════════════════════════

    function test_PauseBlocksDeposit() external {
        _register(sender1);
        vm.prank(owner);
        treasury.pause();
        vm.prank(sender1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        treasury.deposit{value: 1 ether}(creator);
    }

    function test_PauseBlocksWithdraw() external {
        _register(sender1);
        vm.prank(sender1);
        treasury.deposit{value: 1 ether}(creator);
        vm.prank(owner);
        treasury.pause();
        vm.prank(owner);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        treasury.withdraw();
    }

    function test_UnpauseRestoresOperations() external {
        _register(sender1);
        vm.startPrank(owner);
        treasury.pause();
        treasury.unpause();
        vm.stopPrank();
        vm.prank(sender1);
        treasury.deposit{value: 1 ether}(creator);
        assertEq(treasury.allocations(owner), 1 ether);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Ownable2Step
    // ════════════════════════════════════════════════════════════════════════

    function test_OwnershipTransferRequiresTwoStep() external {
        address nominee = makeAddr("nominee");
        vm.prank(owner);
        treasury.transferOwnership(nominee);
        assertEq(treasury.owner(), owner);
        assertEq(treasury.pendingOwner(), nominee);
        vm.prank(nominee);
        treasury.acceptOwnership();
        assertEq(treasury.owner(), nominee);
    }

    // ════════════════════════════════════════════════════════════════════════
    // totalBalance
    // ════════════════════════════════════════════════════════════════════════

    function test_TotalBalanceReflectsContractETH() external {
        _register(sender1);
        vm.prank(sender1);
        treasury.deposit{value: 3 ether}(creator);
        assertEq(treasury.totalBalance(), 3 ether);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Fuzz
    // ════════════════════════════════════════════════════════════════════════

    function testFuzz_DepositAllocationsAlwaysSumToDeposit(uint256 amount) external {
        amount = bound(amount, 1, 1_000 ether);
        vm.deal(sender1, amount);
        _register(sender1);
        Treasury.FeeSplitEntry[] memory split = _splitAB(3_000, 7_000);
        vm.prank(owner);
        treasury.setFeeSplit(split);

        vm.prank(sender1);
        treasury.deposit{value: amount}(creator);

        uint256 total = treasury.allocations(recipientA) + treasury.allocations(recipientB);
        assertEq(total, amount);
    }
}
