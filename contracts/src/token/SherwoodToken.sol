// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SherwoodErrors} from "../errors/SherwoodErrors.sol";

/// @title SherwoodToken
/// @notice ERC-20 launch token whose supply can only be minted by its deploying factory.
/// @dev Ownership is assigned to the launch creator, while mint authority remains immutable.
contract SherwoodToken is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    address public immutable factory;

    modifier onlyFactory() {
        if (msg.sender != factory) revert SherwoodErrors.UnauthorizedFactory();
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address factory_,
        address initialOwner
    ) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(initialOwner) {
        if (factory_ == address(0) || initialOwner == address(0)) {
            revert SherwoodErrors.InvalidAddress();
        }
        factory = factory_;
    }

    /// @notice Mints tokens to a launch project. Only the immutable factory can call this.
    function mint(address to, uint256 amount) external onlyFactory {
        if (to == address(0)) revert SherwoodErrors.InvalidAddress();
        if (amount == 0) revert SherwoodErrors.InvalidTokenAmount();
        _mint(to, amount);
    }
}
