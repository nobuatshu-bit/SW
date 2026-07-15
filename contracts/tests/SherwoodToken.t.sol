// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";

import {SherwoodErrors} from "../src/errors/SherwoodErrors.sol";
import {SherwoodToken} from "../src/token/SherwoodToken.sol";

contract SherwoodTokenTest is Test {
    uint256 internal constant OWNER_KEY = 0xA11CE;
    address internal owner = vm.addr(OWNER_KEY);
    address internal factory = makeAddr("factory");
    address internal recipient = makeAddr("recipient");
    address internal spender = makeAddr("spender");

    SherwoodToken internal token;

    function setUp() external {
        token = new SherwoodToken("Sherwood Token", "SHW", factory, owner);
    }

    function test_ConstructorSetsOwnerAndFactory() external view {
        assertEq(token.owner(), owner);
        assertEq(token.factory(), factory);
        assertEq(token.name(), "Sherwood Token");
        assertEq(token.symbol(), "SHW");
    }

    function test_MintIsRestrictedToFactory() external {
        vm.prank(factory);
        token.mint(recipient, 100 ether);
        assertEq(token.balanceOf(recipient), 100 ether);

        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.UnauthorizedFactory.selector);
        token.mint(recipient, 1 ether);
    }

    function test_MintRejectsZeroRecipientAndZeroAmount() external {
        vm.startPrank(factory);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        token.mint(address(0), 1 ether);
        vm.expectRevert(SherwoodErrors.InvalidTokenAmount.selector);
        token.mint(recipient, 0);
        vm.stopPrank();
    }

    function test_BurnDestroysHolderTokens() external {
        vm.prank(factory);
        token.mint(recipient, 100 ether);

        vm.prank(recipient);
        token.burn(40 ether);
        assertEq(token.balanceOf(recipient), 60 ether);
        assertEq(token.totalSupply(), 60 ether);
    }

    function test_PermitSetsAllowance() external {
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 123 ether;
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
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_KEY, digest);

        token.permit(owner, spender, value, deadline, v, r, s);
        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), 1);
    }
}
