// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";

import {SherwoodFactory} from "../src/factory/SherwoodFactory.sol";
import {LaunchProject} from "../src/launchpad/LaunchProject.sol";

/// @notice Deploys the version-one launch implementation and its Base Sepolia factory.
contract DeploySherwood is Script {
    function run() external returns (SherwoodFactory factory, LaunchProject implementation) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        uint16 protocolFeeBps = uint16(vm.envOr("PROTOCOL_FEE_BPS", uint256(250)));

        vm.startBroadcast(deployerPrivateKey);
        implementation = new LaunchProject();
        factory = new SherwoodFactory(deployer, address(implementation), feeRecipient, protocolFeeBps);
        vm.stopBroadcast();
    }
}
