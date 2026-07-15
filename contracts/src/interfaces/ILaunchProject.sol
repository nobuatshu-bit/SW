// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {LaunchTypes} from "../libraries/LaunchTypes.sol";

interface ILaunchProject {
    function initialize(LaunchTypes.LaunchInit calldata init) external;
    function state() external view returns (LaunchTypes.ProjectState);
}
