// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test}     from "forge-std/Test.sol";
import {Ownable}  from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20}    from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Vesting}         from "../src/vesting/Vesting.sol";
import {SherwoodErrors}  from "../src/errors/SherwoodErrors.sol";
import {LaunchTypes}     from "../src/libraries/LaunchTypes.sol";
import {LaunchConstants} from "../src/utils/LaunchConstants.sol";

// ── Minimal ERC-20 ────────────────────────────────────────────────────────────
contract VestToken is ERC20 {
    constructor() ERC20("Vest Token", "VST") { _mint(msg.sender, 100_000_000 ether); }
}

// ── Vesting test suite ────────────────────────────────────────────────────────
contract VestingTest is Test {

    // ── Actors ────────────────────────────────────────────────────────────────
    address internal owner         = makeAddr("owner");
    address internal beneficiary1  = makeAddr("beneficiary1");
    address internal beneficiary2  = makeAddr("beneficiary2");
    address internal stranger      = makeAddr("stranger");

    // ── Contracts ─────────────────────────────────────────────────────────────
    VestToken internal token;
    Vesting   internal vesting;

    // ── Schedule constants ────────────────────────────────────────────────────
    uint256 internal constant TOTAL       = 120_000 ether;
    uint64  internal constant CLIFF       = 6  * 30 days;   // 6 months
    uint64  internal constant DURATION    = 24 * 30 days;   // 24 months

    // ── Setup ─────────────────────────────────────────────────────────────────
    function setUp() external {
        vm.startPrank(owner);
        token   = new VestToken();
        vesting = new Vesting(address(token), owner);
        token.approve(address(vesting), type(uint256).max);
        vm.stopPrank();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _startTime() internal view returns (uint64) {
        return uint64(block.timestamp);
    }

    function _createSchedule(address ben) internal {
        vm.prank(owner);
        vesting.createSchedule(ben, TOTAL, _startTime(), CLIFF, DURATION);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════

    function test_ConstructorSetsTokenAndOwner() external view {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.owner(),          owner);
    }

    function test_ConstructorRevertsOnZeroToken() external {
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        new Vesting(address(0), owner);
    }

    function test_ConstructorRevertsOnZeroOwner() external {
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0))
        );
        new Vesting(address(token), address(0));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // createSchedule
    // ══════════════════════════════════════════════════════════════════════════

    function test_CreateScheduleStoresParametersAndPullsTokens() external {
        uint256 ownerBefore = token.balanceOf(owner);
        _createSchedule(beneficiary1);

        LaunchTypes.VestingSchedule memory s = vesting.getSchedule(beneficiary1);
        assertEq(s.totalAmount,     TOTAL);
        assertEq(s.claimed,         0);
        assertEq(s.cliffDuration,   CLIFF);
        assertEq(s.vestingDuration, DURATION);
        assertFalse(s.revoked);

        assertEq(token.balanceOf(address(vesting)), TOTAL);
        assertEq(token.balanceOf(owner),            ownerBefore - TOTAL);
    }

    function test_CreateScheduleEmitsEvent() external {
        uint64 start = _startTime();
        vm.expectEmit(true, false, false, true);
        emit Vesting.ScheduleCreated(beneficiary1, TOTAL, start, CLIFF, DURATION);
        vm.prank(owner);
        vesting.createSchedule(beneficiary1, TOTAL, start, CLIFF, DURATION);
    }

    function test_CreateScheduleRevertsOnZeroBeneficiary() external {
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        vesting.createSchedule(address(0), TOTAL, _startTime(), CLIFF, DURATION);
    }

    function test_CreateScheduleRevertsOnZeroAmount() external {
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidTokenAmount.selector);
        vesting.createSchedule(beneficiary1, 0, _startTime(), CLIFF, DURATION);
    }

    function test_CreateScheduleRevertsWhenDurationNotGreaterThanCliff() external {
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidDuration.selector);
        vesting.createSchedule(beneficiary1, TOTAL, _startTime(), CLIFF, CLIFF);
    }

    function test_CreateScheduleRevertsWhenDurationExceedsMax() external {
        uint64 over = LaunchConstants.MAX_VESTING_DURATION + 1;
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidDuration.selector);
        vesting.createSchedule(beneficiary1, TOTAL, _startTime(), 0, over);
    }

    function test_CreateScheduleRevertsIfActiveScheduleExists() external {
        _createSchedule(beneficiary1);
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.ScheduleAlreadyExists.selector, beneficiary1)
        );
        vesting.createSchedule(beneficiary1, TOTAL, _startTime(), CLIFF, DURATION);
    }

    function test_CreateScheduleRevertsForNonOwner() external {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger)
        );
        vesting.createSchedule(beneficiary1, TOTAL, _startTime(), CLIFF, DURATION);
    }

    function test_CreateScheduleAllowsNewScheduleAfterRevocation() external {
        _createSchedule(beneficiary1);

        vm.prank(owner);
        vesting.revoke(beneficiary1);

        // Should not revert
        vm.prank(owner);
        vesting.createSchedule(beneficiary1, TOTAL, _startTime(), CLIFF, DURATION);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // vestedAmount
    // ══════════════════════════════════════════════════════════════════════════

    function test_VestedAmountIsZeroBeforeCliff() external {
        _createSchedule(beneficiary1);
        vm.warp(block.timestamp + CLIFF - 1);
        assertEq(vesting.vestedAmount(beneficiary1), 0);
    }

    function test_VestedAmountIsNonZeroAtCliff() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        // At exactly start + cliff, elapsed == cliff, vesting begins
        vm.warp(start + CLIFF);
        uint256 vested = vesting.vestedAmount(beneficiary1);
        uint256 expected = TOTAL * CLIFF / DURATION;
        assertApproxEqAbs(vested, expected, 1);
    }

    function test_VestedAmountIsPartialMidway() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        // Warp to halfway through the vesting period (after cliff)
        vm.warp(start + DURATION / 2);
        uint256 vested = vesting.vestedAmount(beneficiary1);
        uint256 expected = TOTAL * (DURATION / 2) / DURATION;
        assertApproxEqAbs(vested, expected, 1);
    }

    function test_VestedAmountIsFullAtEnd() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        vm.warp(start + DURATION);
        assertEq(vesting.vestedAmount(beneficiary1), TOTAL);
    }

    function test_VestedAmountIsFullPastEnd() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        vm.warp(start + DURATION + 365 days);
        assertEq(vesting.vestedAmount(beneficiary1), TOTAL);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // claimableAmount
    // ══════════════════════════════════════════════════════════════════════════

    function test_ClaimableAmountIsZeroBeforeCliff() external {
        _createSchedule(beneficiary1);
        vm.warp(block.timestamp + CLIFF - 1);
        assertEq(vesting.claimableAmount(beneficiary1), 0);
    }

    function test_ClaimableAmountDecreasesAfterClaim() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        vm.warp(start + DURATION / 2);

        uint256 claimable = vesting.claimableAmount(beneficiary1);
        assertTrue(claimable > 0);

        vm.prank(beneficiary1);
        vesting.claim();

        assertEq(vesting.claimableAmount(beneficiary1), 0);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // claim
    // ══════════════════════════════════════════════════════════════════════════

    function test_ClaimTransfersVestedTokens() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        vm.warp(start + DURATION);

        uint256 before = token.balanceOf(beneficiary1);
        vm.prank(beneficiary1);
        vesting.claim();

        assertEq(token.balanceOf(beneficiary1), before + TOTAL);
        assertEq(vesting.getSchedule(beneficiary1).claimed, TOTAL);
    }

    function test_ClaimRevertsBeforeCliff() external {
        _createSchedule(beneficiary1);
        vm.prank(beneficiary1);
        vm.expectRevert(SherwoodErrors.NoVestedTokens.selector);
        vesting.claim();
    }

    function test_ClaimRevertsForUnregisteredBeneficiary() external {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.ScheduleNotFound.selector, stranger)
        );
        vesting.claim();
    }

    function test_ClaimRevertsWhenPaused() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        vm.warp(start + DURATION);
        vm.prank(owner);
        vesting.pause();
        vm.prank(beneficiary1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vesting.claim();
    }

    function test_ClaimEmitsEvent() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        vm.warp(start + DURATION);
        uint256 claimable = vesting.claimableAmount(beneficiary1);

        vm.expectEmit(true, false, false, true);
        emit Vesting.TokensClaimed(beneficiary1, claimable, claimable);
        vm.prank(beneficiary1);
        vesting.claim();
    }

    function test_ClaimAccumulatesCorrectlyOverMultipleClaims() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);

        vm.warp(start + DURATION / 3);
        vm.prank(beneficiary1);
        vesting.claim();
        uint256 firstClaim = vesting.getSchedule(beneficiary1).claimed;

        vm.warp(start + (DURATION * 2) / 3);
        vm.prank(beneficiary1);
        vesting.claim();
        uint256 secondClaim = vesting.getSchedule(beneficiary1).claimed - firstClaim;

        vm.warp(start + DURATION);
        vm.prank(beneficiary1);
        vesting.claim();
        uint256 thirdClaim = vesting.getSchedule(beneficiary1).claimed - firstClaim - secondClaim;

        assertEq(firstClaim + secondClaim + thirdClaim, TOTAL);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // revoke
    // ══════════════════════════════════════════════════════════════════════════

    function test_RevokeReturnsUnvestedTokensToOwner() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        vm.warp(start + DURATION / 2);

        uint256 vested   = vesting.vestedAmount(beneficiary1);
        uint256 unvested = TOTAL - vested;
        uint256 before   = token.balanceOf(owner);

        vm.prank(owner);
        vesting.revoke(beneficiary1);

        assertEq(token.balanceOf(owner), before + unvested);
    }

    function test_RevokeMarksScheduleAsRevoked() external {
        _createSchedule(beneficiary1);
        vm.prank(owner);
        vesting.revoke(beneficiary1);
        assertTrue(vesting.getSchedule(beneficiary1).revoked);
    }

    function test_RevokeEmitsEvent() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        vm.warp(start + DURATION / 2);
        uint256 unvested = TOTAL - vesting.vestedAmount(beneficiary1);

        vm.expectEmit(true, false, false, true);
        emit Vesting.ScheduleRevoked(beneficiary1, unvested);
        vm.prank(owner);
        vesting.revoke(beneficiary1);
    }

    function test_RevokeAllowsBeneficiaryToClaimVested() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        vm.warp(start + DURATION / 2);

        uint256 vested = vesting.vestedAmount(beneficiary1);
        vm.prank(owner);
        vesting.revoke(beneficiary1);

        uint256 before = token.balanceOf(beneficiary1);
        vm.prank(beneficiary1);
        vesting.claim();
        assertApproxEqAbs(token.balanceOf(beneficiary1), before + vested, 1);
    }

    function test_RevokeRevertsForNonOwner() external {
        _createSchedule(beneficiary1);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger)
        );
        vesting.revoke(beneficiary1);
    }

    function test_RevokeRevertsForUnknownBeneficiary() external {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.ScheduleNotFound.selector, stranger)
        );
        vesting.revoke(stranger);
    }

    function test_RevokeRevertsIfAlreadyRevoked() external {
        _createSchedule(beneficiary1);
        vm.prank(owner);
        vesting.revoke(beneficiary1);
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(SherwoodErrors.ScheduleRevoked.selector, beneficiary1)
        );
        vesting.revoke(beneficiary1);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Pause / Unpause
    // ══════════════════════════════════════════════════════════════════════════

    function test_PauseBlocksClaim() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        vm.warp(start + DURATION);
        vm.prank(owner);
        vesting.pause();
        vm.prank(beneficiary1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vesting.claim();
    }

    function test_UnpauseRestoresClaim() external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        vm.warp(start + DURATION);
        vm.startPrank(owner);
        vesting.pause();
        vesting.unpause();
        vm.stopPrank();
        vm.prank(beneficiary1);
        vesting.claim();
        assertEq(token.balanceOf(beneficiary1), TOTAL);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Registry views
    // ══════════════════════════════════════════════════════════════════════════

    function test_BeneficiaryCountAndAt() external {
        _createSchedule(beneficiary1);
        vm.prank(owner);
        vesting.createSchedule(beneficiary2, TOTAL, _startTime(), CLIFF, DURATION);
        assertEq(vesting.beneficiaryCount(), 2);
        assertEq(vesting.beneficiaryAt(0), beneficiary1);
        assertEq(vesting.beneficiaryAt(1), beneficiary2);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Fuzz
    // ══════════════════════════════════════════════════════════════════════════

    function testFuzz_VestedAmountNeverExceedsTotal(uint256 warpSeconds) external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        warpSeconds = bound(warpSeconds, 0, 10 * 365 days);
        vm.warp(start + warpSeconds);
        assertLe(vesting.vestedAmount(beneficiary1), TOTAL);
    }

    function testFuzz_ClaimableNeverExceedsVested(uint256 warpSeconds) external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);
        warpSeconds = bound(warpSeconds, 0, 10 * 365 days);
        vm.warp(start + warpSeconds);
        assertLe(vesting.claimableAmount(beneficiary1), vesting.vestedAmount(beneficiary1));
    }

    // ════════════════════════════════════════════════════════════════════════
    // Sprint 8 — HIGH-1: beneficiary enumeration deduplication
    // ════════════════════════════════════════════════════════════════════════

    function test_RevokeAndRescheduleDoesNotDuplicateBeneficiary() external {
        _createSchedule(beneficiary1);
        assertEq(vesting.beneficiaryCount(), 1);

        vm.prank(owner);
        vesting.revoke(beneficiary1);

        vm.prank(owner);
        vesting.createSchedule(beneficiary1, TOTAL, _startTime(), CLIFF, DURATION);

        assertEq(vesting.beneficiaryCount(), 1);
        assertEq(vesting.beneficiaryAt(0), beneficiary1);
    }

    function test_TwoBeneficiariesHaveCount2() external {
        _createSchedule(beneficiary1);
        vm.prank(owner);
        vesting.createSchedule(beneficiary2, TOTAL, _startTime(), CLIFF, DURATION);

        assertEq(vesting.beneficiaryCount(), 2);
        assertEq(vesting.beneficiaryAt(0), beneficiary1);
        assertEq(vesting.beneficiaryAt(1), beneficiary2);
    }

    function test_RevokeRescheduleWithOtherBeneficiaryKeepsCorrectCount() external {
        _createSchedule(beneficiary1);
        vm.prank(owner);
        vesting.revoke(beneficiary1);

        vm.prank(owner);
        vesting.createSchedule(beneficiary2, TOTAL, _startTime(), CLIFF, DURATION);

        vm.prank(owner);
        vesting.createSchedule(beneficiary1, TOTAL, _startTime(), CLIFF, DURATION);

        assertEq(vesting.beneficiaryCount(), 2);
    }

    function testFuzz_RescheduleClaimNeverExceedsNewTotal(uint256 warpSeconds) external {
        uint64 start = _startTime();
        _createSchedule(beneficiary1);

        warpSeconds = bound(warpSeconds, uint256(CLIFF), uint256(DURATION));
        vm.warp(start + warpSeconds);

        vm.prank(owner);
        vesting.revoke(beneficiary1);

        vm.prank(owner);
        vesting.createSchedule(beneficiary1, TOTAL, uint64(block.timestamp), CLIFF, DURATION);

        LaunchTypes.VestingSchedule memory s = vesting.getSchedule(beneficiary1);
        assertEq(s.claimed, 0);
        assertEq(s.totalAmount, TOTAL);
        assertFalse(s.revoked);
    }
}