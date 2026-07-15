// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";

import {SherwoodErrors} from "../src/errors/SherwoodErrors.sol";
import {SherwoodFactory} from "../src/factory/SherwoodFactory.sol";
import {LaunchProject} from "../src/launchpad/LaunchProject.sol";
import {LaunchTypes} from "../src/libraries/LaunchTypes.sol";
import {SherwoodToken} from "../src/token/SherwoodToken.sol";

contract SherwoodFactoryTest is Test {
    address internal owner = makeAddr("owner");
    address internal creator = makeAddr("creator");
    address internal feeRecipient = makeAddr("feeRecipient");
    address internal replacementRecipient = makeAddr("replacementRecipient");

    LaunchProject internal implementation;
    SherwoodFactory internal factory;

    function setUp() external {
        implementation = new LaunchProject();
        factory = new SherwoodFactory(owner, address(implementation), feeRecipient, 250);
    }

    function test_ConstructorStoresInitialConfiguration() external view {
        assertEq(factory.owner(), owner);
        assertEq(factory.feeRecipient(), feeRecipient);
        assertEq(factory.protocolFeeBps(), 250);
        assertEq(factory.launchProjectImplementation(), address(implementation));
    }

    function test_CreateLaunchDeploysAndRegistersTokenAndProject() external {
        vm.prank(creator);
        (address projectAddress, address tokenAddress) = factory.createLaunch(_params());

        LaunchProject project = LaunchProject(payable(projectAddress));
        SherwoodToken token = SherwoodToken(tokenAddress);
        LaunchTypes.LaunchInfo memory info = factory.getLaunch(projectAddress);

        assertEq(factory.projectCount(), 1);
        assertEq(factory.projectAt(0), projectAddress);
        assertEq(project.creator(), creator);
        assertEq(project.factory(), address(factory));
        assertEq(address(project.saleToken()), tokenAddress);
        assertEq(uint8(project.state()), uint8(LaunchTypes.ProjectState.Pending));
        assertEq(token.owner(), creator);
        assertEq(token.factory(), address(factory));
        assertEq(token.balanceOf(projectAddress), _params().saleTokenAllocation);
        assertEq(info.creator, creator);
        assertEq(info.token, tokenAddress);
        assertEq(info.protocolFeeBps, 250);
    }

    function test_CreateLaunchRejectsInvalidConfiguration() external {
        LaunchTypes.CreateLaunchParams memory params = _params();
        params.tokenName = "";

        vm.prank(creator);
        vm.expectRevert(SherwoodErrors.InvalidLaunchConfiguration.selector);
        factory.createLaunch(params);
    }

    function test_PausePreventsLaunchCreationAndUnpauseRestoresIt() external {
        vm.prank(owner);
        factory.pause();

        vm.prank(creator);
        vm.expectRevert();
        factory.createLaunch(_params());

        vm.prank(owner);
        factory.unpause();
        vm.prank(creator);
        factory.createLaunch(_params());

        assertEq(factory.projectCount(), 1);
    }

    function test_PauseAndUnpauseRequireOwner() external {
        vm.prank(creator);
        vm.expectRevert();
        factory.pause();

        vm.prank(owner);
        factory.pause();
        vm.prank(creator);
        vm.expectRevert();
        factory.unpause();
    }

    function test_SetProtocolFeeUpdatesValueAndRejectsOutOfRangeFee() external {
        vm.prank(owner);
        factory.setProtocolFee(500);
        assertEq(factory.protocolFeeBps(), 500);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(SherwoodErrors.InvalidFeeBps.selector, 1_001));
        factory.setProtocolFee(1_001);
    }

    function test_SetProtocolFeeRequiresOwner() external {
        vm.prank(creator);
        vm.expectRevert();
        factory.setProtocolFee(100);
    }

    function test_SetFeeRecipientUpdatesValueAndRejectsZeroAddress() external {
        vm.prank(owner);
        factory.setFeeRecipient(replacementRecipient);
        assertEq(factory.feeRecipient(), replacementRecipient);

        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        factory.setFeeRecipient(address(0));
    }

    function test_SetFeeRecipientRequiresOwner() external {
        vm.prank(creator);
        vm.expectRevert();
        factory.setFeeRecipient(replacementRecipient);
    }

    function test_SetLaunchProjectImplementationUsesNewVersionForFutureLaunches() external {
        LaunchProject newImplementation = new LaunchProject();
        vm.prank(owner);
        factory.setLaunchProjectImplementation(address(newImplementation));

        assertEq(factory.launchProjectImplementation(), address(newImplementation));

        vm.prank(creator);
        (address project,) = factory.createLaunch(_params());
        assertTrue(project.code.length > 0);
    }

    function test_SetLaunchProjectImplementationRejectsInvalidAddressAndRequiresOwner() external {
        vm.prank(owner);
        vm.expectRevert(SherwoodErrors.InvalidAddress.selector);
        factory.setLaunchProjectImplementation(address(0));

        vm.prank(creator);
        vm.expectRevert();
        factory.setLaunchProjectImplementation(address(implementation));
    }

    function _params() internal view returns (LaunchTypes.CreateLaunchParams memory) {
        return LaunchTypes.CreateLaunchParams({
            tokenName: "Sherwood Test Token",
            tokenSymbol: "SWT",
            saleTokenAllocation: 1_000_000 ether,
            tokenPrice: 0.01 ether,
            softCap: 1 ether,
            maxRaise: 100 ether,
            startTime: uint64(block.timestamp + 1 hours),
            endTime: uint64(block.timestamp + 2 hours)
        });
    }
}
