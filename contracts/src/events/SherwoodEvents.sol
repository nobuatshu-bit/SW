// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {LaunchTypes} from "../libraries/LaunchTypes.sol";

abstract contract SherwoodEvents {
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event LaunchActivated(address indexed project, uint256 activatedAt);
    event LaunchCancelled(address indexed project, address indexed cancelledBy);
    event LaunchFinalized(address indexed project, LaunchTypes.ProjectState indexed state, uint256 totalRaised);
    event LaunchProjectImplementationUpdated(address indexed previousImplementation, address indexed newImplementation);
    event ProjectCreated(address indexed project, address indexed token, address indexed creator);
    event ProtocolFeeCollected(address indexed project, address indexed recipient, uint256 amount);
    event ProtocolFeeUpdated(uint16 previousFeeBps, uint16 newFeeBps);
    event TokensBought(address indexed project, address indexed buyer, uint256 paymentAmount, uint256 tokenAmount);
    event TokensClaimed(address indexed project, address indexed account, uint256 amount, bool refunded);
    event TokensSold(address indexed project, address indexed seller, uint256 paymentAmount, uint256 tokenAmount);
    event TreasuryWithdrawn(address indexed project, address indexed recipient, uint256 amount);
    event UnsoldTokensWithdrawn(address indexed project, address indexed recipient, uint256 amount);
}
