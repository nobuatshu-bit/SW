// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SherwoodErrors} from "../src/errors/SherwoodErrors.sol";
import {SherwoodERC20} from "../src/token/SherwoodERC20.sol";

contract SherwoodERC20Test is Test {
    // ── Test actors ──────────────────────────────────────────────────────────

    uint256 internal constant OWNER_KEY   = 0xA11CE;
    uint256 internal constant HOLDER_KEY  = 0xB0B;

    address internal owner   = vm.addr(OWNER_KEY);
    address internal holder  = vm.addr(HOLDER_KEY);
    address internal spender = makeAddr("spender");
    address internal recipient = makeAddr("recipient");

    // ── Deployment constants ─────────────────────────────────────────────────

    string  internal constant NAME   = "Sherwood Finance";
    string  internal constant SYMBOL = "SHW";
    uint256 internal constant SUPPLY = 1_000_000 ether;

    SherwoodERC20 internal token;

    // ── Setup ────────────────────────────────────────────────────────────────

    function setUp() external {
        token = new SherwoodERC20(NAME, SYMBOL, SUPPLY, owner);
    }

    // ── Construction ─────────────────────────────────────────────────────────

    /// @dev Verifies that all constructor parameters are stored/applied correctly.
    function test_ConstructorSetsMetadataAndMintsSupplyToOwner() external view {
        assertEq(token.name(),        NAME);
        assertEq(token.symbol(),      SYMBOL);
        assertEq(token.decimals(),    18);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(owner), SUPPLY);
        assertEq(token.owner(),       owner);
    }

    /// @dev Zero address as initialOwner must revert.
    ///      OZ5 Ownable checks for address(0) before our guard, so the revert
    ///      selector is OwnableInvalidOwner rather than SherwoodErrors.InvalidAddress.
    function test_ConstructorRevertsOnZeroOwner() external {
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0))
        );
        new SherwoodERC20(NAME, SYMBOL, SUPPLY, address(0));
    }

    /// @dev Zero supply must revert.
    function test_ConstructorRevertsOnZeroSupply() external {
        vm.expectRevert(SherwoodErrors.InvalidTokenAmount.selector);
        new SherwoodERC20(NAME, SYMBOL, 0, owner);
    }

    // ── ERC-20 transfers ─────────────────────────────────────────────────────

    function test_TransferMovesBalance() external {
        uint256 amount = 500 ether;

        vm.prank(owner);
        token.transfer(recipient, amount);

        assertEq(token.balanceOf(owner),     SUPPLY - amount);
        assertEq(token.balanceOf(recipient), amount);
    }

    function test_ApproveAndTransferFrom() external {
        uint256 amount = 200 ether;

        vm.prank(owner);
        token.approve(spender, amount);

        assertEq(token.allowance(owner, spender), amount);

        vm.prank(spender);
        token.transferFrom(owner, recipient, amount);

        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.allowance(owner, spender), 0);
    }

    // ── ERC-2612 permit ──────────────────────────────────────────────────────

    function test_PermitSetsAllowanceWithoutOnChainApproval() external {
        uint256 value    = 999 ether;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                token.nonces(owner),
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_KEY, digest);

        token.permit(owner, spender, value, deadline, v, r, s);

        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), 1);
    }

    function test_PermitRevertsOnExpiredDeadline() external {
        uint256 deadline = block.timestamp - 1;
        bytes32 digest   = keccak256("dummy");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_KEY, digest);

        vm.expectRevert();
        token.permit(owner, spender, 1 ether, deadline, v, r, s);
    }

    // ── ERC-20Burnable ───────────────────────────────────────────────────────

    function test_BurnReducesTotalSupply() external {
        uint256 burnAmount = 100 ether;

        vm.prank(owner);
        token.burn(burnAmount);

        assertEq(token.totalSupply(),    SUPPLY - burnAmount);
        assertEq(token.balanceOf(owner), SUPPLY - burnAmount);
    }

    function test_BurnFromRequiresAllowance() external {
        uint256 burnAmount = 50 ether;

        vm.prank(owner);
        token.transfer(holder, burnAmount);

        // spender has no allowance — must revert
        vm.prank(spender);
        vm.expectRevert();
        token.burnFrom(holder, burnAmount);

        // grant allowance, then burn succeeds
        vm.prank(holder);
        token.approve(spender, burnAmount);

        vm.prank(spender);
        token.burnFrom(holder, burnAmount);

        assertEq(token.balanceOf(holder), 0);
        assertEq(token.totalSupply(),     SUPPLY - burnAmount);
    }

    // ── ownerBurn ────────────────────────────────────────────────────────────

    function test_OwnerBurnReducesTargetBalanceAndTotalSupply() external {
        uint256 amount = 300 ether;

        vm.prank(owner);
        token.transfer(holder, amount);

        uint256 supplyBefore = token.totalSupply();

        vm.prank(owner);
        token.ownerBurn(holder, amount);

        assertEq(token.balanceOf(holder), 0);
        assertEq(token.totalSupply(),     supplyBefore - amount);
    }

    function test_OwnerBurnRevertsOnZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        token.ownerBurn(address(0), 1 ether);
    }

    function test_OwnerBurnRevertsOnZeroAmount() external {
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidTokenAmount.selector);
        token.ownerBurn(holder, 0);
    }

    function test_OwnerBurnRevertsWhenCalledByNonOwner() external {
        vm.prank(owner);
        token.transfer(holder, 100 ether);

        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, holder));
        token.ownerBurn(holder, 50 ether);
    }

    // ── Pausable ─────────────────────────────────────────────────────────────

    function test_PauseBlocksTransfers() external {
        vm.prank(owner);
        token.pause();

        assertTrue(token.paused());

        vm.prank(owner);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.transfer(recipient, 1 ether);
    }

    function test_PauseBlocksBurns() external {
        vm.prank(owner);
        token.pause();

        vm.prank(owner);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.burn(1 ether);
    }

    function test_UnpauseRestoresTransfers() external {
        vm.startPrank(owner);
        token.pause();
        token.unpause();
        vm.stopPrank();

        assertFalse(token.paused());

        vm.prank(owner);
        token.transfer(recipient, 1 ether);
        assertEq(token.balanceOf(recipient), 1 ether);
    }

    function test_PauseRevertsWhenCalledByNonOwner() external {
        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, holder));
        token.pause();
    }

    function test_UnpauseRevertsWhenCalledByNonOwner() external {
        vm.prank(owner);
        token.pause();

        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, holder));
        token.unpause();
    }

    function test_PauseRevertsIfAlreadyPaused() external {
        vm.startPrank(owner);
        token.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.pause();
        vm.stopPrank();
    }

    function test_UnpauseRevertsIfNotPaused() external {
        vm.prank(owner);
        vm.expectRevert(Pausable.ExpectedPause.selector);
        token.unpause();
    }

    // ── Ownable ──────────────────────────────────────────────────────────────

    function test_TransferOwnership() external {
        vm.prank(owner);
        token.transferOwnership(holder);
        assertEq(token.owner(), holder);
    }

    function test_RenounceOwnership() external {
        vm.prank(owner);
        token.renounceOwnership();
        assertEq(token.owner(), address(0));
    }

    // ── Fuzz ─────────────────────────────────────────────────────────────────

    /// @dev Fuzz total supply construction: any non-zero supply should deploy.
    function testFuzz_ConstructorMintsExactSupply(uint256 supply) external {
        vm.assume(supply > 0 && supply <= 1_000_000_000_000 ether);
        SherwoodERC20 t = new SherwoodERC20(NAME, SYMBOL, supply, owner);
        assertEq(t.totalSupply(),    supply);
        assertEq(t.balanceOf(owner), supply);
    }

    /// @dev Fuzz transfer: any amount up to the owner's balance should succeed.
    function testFuzz_TransferSucceedsForValidAmounts(uint256 amount) external {
        vm.assume(amount > 0 && amount <= SUPPLY);
        vm.prank(owner);
        token.transfer(recipient, amount);
        assertEq(token.balanceOf(recipient), amount);
    }
}
