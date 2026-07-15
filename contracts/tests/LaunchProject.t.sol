// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";

import {SherwoodErrors} from "../src/errors/SherwoodErrors.sol";
import {SherwoodFactory} from "../src/factory/SherwoodFactory.sol";
import {LaunchProject} from "../src/launchpad/LaunchProject.sol";
import {LaunchTypes} from "../src/libraries/LaunchTypes.sol";
import {SherwoodToken} from "../src/token/SherwoodToken.sol";

contract LaunchProjectTest is Test {
    address internal owner = makeAddr("owner");
    address internal creator = makeAddr("creator");
    address internal buyer = makeAddr("buyer");
    address internal other = makeAddr("other");
    address internal feeRecipient = makeAddr("feeRecipient");

    LaunchProject internal implementation;
    SherwoodFactory internal factory;

    function setUp() external {
        implementation = new LaunchProject();
        factory = new SherwoodFactory(owner, address(implementation), feeRecipient, 250);
        vm.deal(buyer, 100 ether);
        vm.deal(other, 100 ether);
    }

    function test_ImplementationCannotBeInitialized() external {
        vm.expectRevert(SherwoodErrors.AlreadyInitialized.selector);
        implementation.initialize(_init(address(implementation), address(0xBEEF)));
    }

    function test_ProjectRejectsSecondInitialization() external {
        (LaunchProject project,) = _create(_params());

        vm.expectRevert(SherwoodErrors.AlreadyInitialized.selector);
        project.initialize(_init(address(project), address(0xBEEF)));
    }

    function test_ActivateTransitionsPendingProjectToLive() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);

        vm.expectRevert(SherwoodErrors.SaleNotStarted.selector);
        project.activate();

        vm.warp(params.startTime);
        project.activate();
        assertEq(uint8(project.state()), uint8(LaunchTypes.ProjectState.Live));
    }

    function test_BuyTracksAllocationAndProceeds() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);
        _activate(project, params);

        vm.prank(buyer);
        project.buy{value: 2 ether}();

        assertEq(project.purchasedTokens(buyer), 200 ether);
        assertEq(project.contributions(buyer), 2 ether);
        assertEq(project.totalOutstandingTokens(), 200 ether);
        assertEq(project.totalRaised(), 2 ether);
        assertEq(project.protocolFeesAccrued(), 0.05 ether);
        assertEq(project.creatorProceedsAccrued(), 1.95 ether);
    }

    function test_BuyRejectsZeroPaymentAndExcessRaise() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);
        _activate(project, params);

        vm.prank(buyer);
        vm.expectRevert(SherwoodErrors.InvalidPaymentAmount.selector);
        project.buy{value: 0}();

        vm.prank(buyer);
        vm.expectRevert(SherwoodErrors.MaximumRaiseExceeded.selector);
        project.buy{value: 11 ether}();
    }

    function test_BuyRejectsWhenNotLiveOrAfterSaleEnd() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);

        vm.prank(buyer);
        vm.expectRevert(SherwoodErrors.SaleNotLive.selector);
        project.buy{value: 1 ether}();

        vm.warp(params.startTime);
        project.activate();
        vm.warp(params.endTime);
        vm.prank(buyer);
        vm.expectRevert(SherwoodErrors.SaleEnded.selector);
        project.buy{value: 1 ether}();
    }

    function test_SellRefundsUnclaimedAllocationAndRecalculatesFees() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);
        _activate(project, params);

        vm.prank(buyer);
        project.buy{value: 2 ether}();
        uint256 balanceBefore = buyer.balance;

        vm.prank(buyer);
        project.sell(50 ether);

        assertEq(buyer.balance, balanceBefore + 0.5 ether);
        assertEq(project.purchasedTokens(buyer), 150 ether);
        assertEq(project.contributions(buyer), 1.5 ether);
        assertEq(project.totalRaised(), 1.5 ether);
        assertEq(project.protocolFeesAccrued(), 0.0375 ether);
        assertEq(project.creatorProceedsAccrued(), 1.4625 ether);
    }

    function test_SellRejectsZeroOrUnownedAllocation() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);
        _activate(project, params);

        vm.prank(buyer);
        vm.expectRevert(SherwoodErrors.InvalidTokenAmount.selector);
        project.sell(0);

        vm.prank(buyer);
        vm.expectRevert(SherwoodErrors.InvalidTokenAmount.selector);
        project.sell(1 ether);
    }

    function test_FinalizeGraduatesReachedSoftCap() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);
        _activate(project, params);
        vm.prank(buyer);
        project.buy{value: 2 ether}();

        vm.warp(params.endTime);
        project.finalize();

        assertEq(uint8(project.state()), uint8(LaunchTypes.ProjectState.Graduated));
    }

    function test_FinalizeCancelsUnactivatedOrUnderfundedLaunch() external {
        LaunchTypes.CreateLaunchParams memory pendingParams = _params();
        (LaunchProject pendingProject,) = _create(pendingParams);
        vm.warp(pendingParams.endTime);
        pendingProject.finalize();
        assertEq(uint8(pendingProject.state()), uint8(LaunchTypes.ProjectState.Cancelled));

        LaunchTypes.CreateLaunchParams memory liveParams = _params();
        (LaunchProject liveProject,) = _create(liveParams);
        _activate(liveProject, liveParams);
        vm.prank(buyer);
        liveProject.buy{value: 1 ether}();
        vm.warp(liveParams.endTime);
        liveProject.finalize();
        assertEq(uint8(liveProject.state()), uint8(LaunchTypes.ProjectState.Cancelled));
    }

    function test_FinalizeRejectsEarlyOrTerminalState() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);

        vm.expectRevert(SherwoodErrors.SaleNotFinished.selector);
        project.finalize();

        vm.warp(params.endTime);
        project.finalize();
        vm.expectRevert(abi.encodeWithSelector(SherwoodErrors.InvalidProjectState.selector, LaunchTypes.ProjectState.Cancelled));
        project.finalize();
    }

    function test_CancelRequiresCreatorAndPreEndSale() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);

        vm.prank(other);
        vm.expectRevert(SherwoodErrors.Unauthorized.selector);
        project.cancel();

        vm.prank(creator);
        project.cancel();
        assertEq(uint8(project.state()), uint8(LaunchTypes.ProjectState.Cancelled));

        LaunchTypes.CreateLaunchParams memory expiredParams = _params();
        (LaunchProject expiredProject,) = _create(expiredParams);
        vm.warp(expiredParams.endTime);
        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.SaleAlreadyEnded.selector);
        expiredProject.cancel();
    }

    function test_ClaimTransfersTokensAfterGraduation() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project, SherwoodToken token) = _create(params);
        _activate(project, params);
        vm.prank(buyer);
        project.buy{value: 2 ether}();
        vm.warp(params.endTime);
        project.finalize();

        vm.prank(buyer);
        project.claim();

        assertEq(token.balanceOf(buyer), 200 ether);
        assertEq(project.purchasedTokens(buyer), 0);
        assertEq(project.totalOutstandingTokens(), 0);
    }

    function test_ClaimRefundsAfterCancellation() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);
        _activate(project, params);
        vm.prank(buyer);
        project.buy{value: 1 ether}();
        vm.warp(params.endTime);
        project.finalize();
        uint256 balanceBefore = buyer.balance;

        vm.prank(buyer);
        project.claim();

        assertEq(buyer.balance, balanceBefore + 1 ether);
        assertEq(project.contributions(buyer), 0);
        assertEq(project.purchasedTokens(buyer), 0);
    }

    function test_ClaimRejectsNoBalanceAndNonTerminalState() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);
        _activate(project, params);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(SherwoodErrors.InvalidProjectState.selector, LaunchTypes.ProjectState.Live));
        project.claim();

        vm.warp(params.endTime);
        project.finalize();
        vm.prank(other);
        vm.expectRevert(SherwoodErrors.NoClaimableBalance.selector);
        project.claim();
    }

    function test_CollectProtocolFeesRequiresRecipientAndGraduation() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);
        _activate(project, params);
        vm.prank(buyer);
        project.buy{value: 2 ether}();

        vm.prank(other);
        vm.expectRevert(SherwoodErrors.Unauthorized.selector);
        project.collectProtocolFees();
        vm.prank(feeRecipient);
        vm.expectRevert(abi.encodeWithSelector(SherwoodErrors.InvalidProjectState.selector, LaunchTypes.ProjectState.Live));
        project.collectProtocolFees();

        vm.warp(params.endTime);
        project.finalize();
        uint256 balanceBefore = feeRecipient.balance;
        vm.prank(feeRecipient);
        project.collectProtocolFees();

        assertEq(feeRecipient.balance, balanceBefore + 0.05 ether);
        assertEq(project.protocolFeesAccrued(), 0);
    }

    function test_WithdrawTreasuryRequiresCreatorAndGraduation() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project,) = _create(params);
        _activate(project, params);
        vm.prank(buyer);
        project.buy{value: 2 ether}();

        vm.prank(other);
        vm.expectRevert(SherwoodErrors.Unauthorized.selector);
        project.withdrawTreasury();

        vm.warp(params.endTime);
        project.finalize();
        uint256 balanceBefore = creator.balance;
        vm.prank(creator);
        project.withdrawTreasury();

        assertEq(creator.balance, balanceBefore + 1.95 ether);
        assertEq(project.creatorProceedsAccrued(), 0);
    }

    function test_WithdrawUnsoldTokensPreservesGraduatedBuyerClaims() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project, SherwoodToken token) = _create(params);
        _activate(project, params);
        vm.prank(buyer);
        project.buy{value: 2 ether}();
        vm.warp(params.endTime);
        project.finalize();

        vm.prank(creator);
        project.withdrawUnsoldTokens();
        assertEq(token.balanceOf(creator), params.saleTokenAllocation - 200 ether);
        assertEq(token.balanceOf(address(project)), 200 ether);

        vm.prank(buyer);
        project.claim();
        assertEq(token.balanceOf(buyer), 200 ether);
    }

    function test_WithdrawUnsoldTokensOnCancellationAndRejectsNonCreator() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        (LaunchProject project, SherwoodToken token) = _create(params);
        vm.prank(creator);
        project.cancel();

        vm.prank(other);
        vm.expectRevert(SherwoodErrors.Unauthorized.selector);
        project.withdrawUnsoldTokens();

        vm.prank(creator);
        project.withdrawUnsoldTokens();
        assertEq(token.balanceOf(creator), params.saleTokenAllocation);
    }

    function _activate(LaunchProject project, LaunchTypes.CreateLaunchParams memory params) internal {
        vm.warp(params.startTime);
        project.activate();
    }

    function _create(LaunchTypes.CreateLaunchParams memory params)
        internal
        returns (LaunchProject project, SherwoodToken token)
    {
        vm.prank(creator);
        (address projectAddress, address tokenAddress) = factory.createLaunch(params);
        project = LaunchProject(payable(projectAddress));
        token = SherwoodToken(tokenAddress);
    }

    function _params() internal view returns (LaunchTypes.CreateLaunchParams memory) {
        return LaunchTypes.CreateLaunchParams({
            tokenName: "Sherwood Test Token",
            tokenSymbol: "SWT",
            saleTokenAllocation: 1_000_000 ether,
            tokenPrice: 0.01 ether,
            softCap: 2 ether,
            maxRaise: 10 ether,
            startTime: uint64(block.timestamp + 1 hours),
            endTime: uint64(block.timestamp + 2 hours)
        });
    }

    function _init(address project, address token) internal view returns (LaunchTypes.LaunchInit memory) {
        return LaunchTypes.LaunchInit({
            factory: address(factory),
            creator: creator,
            token: token,
            feeRecipient: feeRecipient,
            protocolFeeBps: 250,
            saleTokenAllocation: 1 ether,
            tokenPrice: 0.01 ether,
            softCap: 1 ether,
            maxRaise: 2 ether,
            startTime: uint64(block.timestamp + 1 hours),
            endTime: uint64(block.timestamp + 2 hours)
        });
    }
}
