// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {SherwoodErrors} from "../errors/SherwoodErrors.sol";
import {SherwoodEvents} from "../events/SherwoodEvents.sol";
import {ILaunchProject} from "../interfaces/ILaunchProject.sol";
import {LaunchTypes} from "../libraries/LaunchTypes.sol";
import {SherwoodToken} from "../token/SherwoodToken.sol";
import {LaunchConstants} from "../utils/LaunchConstants.sol";

/// @title SherwoodFactory
/// @notice Deploys launch tokens and gas-efficient EIP-1167 launch project clones.
/// @dev Updating `launchProjectImplementation` only changes future launches. This versioned
/// implementation strategy preserves historical project behavior while supporting safe upgrades.
contract SherwoodFactory is Ownable2Step, Pausable, SherwoodEvents {
    address public feeRecipient;
    address public launchProjectImplementation;
    uint16 public protocolFeeBps;

    address[] private _projects;
    mapping(address project => LaunchTypes.LaunchInfo info) private _launches;

    constructor(
        address initialOwner,
        address initialLaunchProjectImplementation,
        address initialFeeRecipient,
        uint16 initialProtocolFeeBps
    ) Ownable(initialOwner) {
        if (initialOwner == address(0) || initialFeeRecipient == address(0)) {
            revert SherwoodErrors.InvalidAddress();
        }
        _setLaunchProjectImplementation(initialLaunchProjectImplementation);
        _setProtocolFee(initialProtocolFeeBps);
        feeRecipient = initialFeeRecipient;
    }

    /// @notice Creates a token and a corresponding fixed-price launch project.
    function createLaunch(LaunchTypes.CreateLaunchParams calldata params)
        external
        whenNotPaused
        returns (address project, address token)
    {
        _validateLaunchParameters(params);

        SherwoodToken launchToken = new SherwoodToken(
            params.tokenName, params.tokenSymbol, address(this), msg.sender
        );
        project = Clones.clone(launchProjectImplementation);
        token = address(launchToken);

        ILaunchProject(project).initialize(
            LaunchTypes.LaunchInit({
                factory: address(this),
                creator: msg.sender,
                token: token,
                feeRecipient: feeRecipient,
                protocolFeeBps: protocolFeeBps,
                saleTokenAllocation: params.saleTokenAllocation,
                tokenPrice: params.tokenPrice,
                softCap: params.softCap,
                maxRaise: params.maxRaise,
                startTime: params.startTime,
                endTime: params.endTime
            })
        );
        launchToken.mint(project, params.saleTokenAllocation);

        _launches[project] = LaunchTypes.LaunchInfo({
            creator: msg.sender,
            token: token,
            saleTokenAllocation: params.saleTokenAllocation,
            tokenPrice: params.tokenPrice,
            softCap: params.softCap,
            maxRaise: params.maxRaise,
            startTime: params.startTime,
            endTime: params.endTime,
            protocolFeeBps: protocolFeeBps
        });
        _projects.push(project);

        emit ProjectCreated(project, token, msg.sender);
    }

    /// @notice Pauses new launch creation without interrupting existing projects.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes new launch creation.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Updates the fee charged to newly created launches.
    function setProtocolFee(uint16 newProtocolFeeBps) external onlyOwner {
        _setProtocolFee(newProtocolFeeBps);
    }

    /// @notice Updates the recipient used by newly created launches.
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert SherwoodErrors.InvalidAddress();
        address previousRecipient = feeRecipient;
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(previousRecipient, newFeeRecipient);
    }

    /// @notice Sets the implementation cloned by future projects.
    function setLaunchProjectImplementation(address newImplementation) external onlyOwner {
        _setLaunchProjectImplementation(newImplementation);
    }

    /// @notice Returns immutable launch configuration registered for a project.
    function getLaunch(address project) external view returns (LaunchTypes.LaunchInfo memory) {
        return _launches[project];
    }

    /// @notice Returns a project address by zero-based launch index.
    function projectAt(uint256 index) external view returns (address) {
        return _projects[index];
    }

    /// @notice Returns the number of launches deployed by this factory.
    function projectCount() external view returns (uint256) {
        return _projects.length;
    }

    function _setProtocolFee(uint16 newProtocolFeeBps) private {
        if (newProtocolFeeBps > LaunchConstants.MAX_PROTOCOL_FEE_BPS) {
            revert SherwoodErrors.InvalidFeeBps(newProtocolFeeBps);
        }
        uint16 previousFeeBps = protocolFeeBps;
        protocolFeeBps = newProtocolFeeBps;
        emit ProtocolFeeUpdated(previousFeeBps, newProtocolFeeBps);
    }

    function _setLaunchProjectImplementation(address newImplementation) private {
        if (newImplementation == address(0) || newImplementation.code.length == 0) {
            revert SherwoodErrors.InvalidAddress();
        }
        address previousImplementation = launchProjectImplementation;
        launchProjectImplementation = newImplementation;
        emit LaunchProjectImplementationUpdated(previousImplementation, newImplementation);
    }

    function _validateLaunchParameters(LaunchTypes.CreateLaunchParams calldata params) private view {
        if (
            bytes(params.tokenName).length == 0 || bytes(params.tokenSymbol).length == 0
                || params.saleTokenAllocation == 0 || params.tokenPrice == 0 || params.softCap == 0
                || params.maxRaise < params.softCap || params.startTime < block.timestamp
                || params.endTime <= params.startTime
        ) revert SherwoodErrors.InvalidLaunchConfiguration();
    }
}
