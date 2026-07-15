// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library LaunchTypes {
    enum ProjectState {
        Pending,
        Live,
        Graduated,
        Cancelled
    }

    struct CreateLaunchParams {
        string tokenName;
        string tokenSymbol;
        uint256 saleTokenAllocation;
        uint256 tokenPrice;
        uint256 softCap;
        uint256 maxRaise;
        uint64 startTime;
        uint64 endTime;
    }

    struct LaunchInit {
        address factory;
        address creator;
        address token;
        address feeRecipient;
        uint16 protocolFeeBps;
        uint256 saleTokenAllocation;
        uint256 tokenPrice;
        uint256 softCap;
        uint256 maxRaise;
        uint64 startTime;
        uint64 endTime;
    }

    struct LaunchInfo {
        address creator;
        address token;
        uint256 saleTokenAllocation;
        uint256 tokenPrice;
        uint256 softCap;
        uint256 maxRaise;
        uint64 startTime;
        uint64 endTime;
        uint16 protocolFeeBps;
    }
}
