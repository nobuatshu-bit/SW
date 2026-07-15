// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ISherwoodFactory {
    function feeRecipient() external view returns (address);
    function protocolFeeBps() external view returns (uint16);
    function launchProjectImplementation() external view returns (address);
}
