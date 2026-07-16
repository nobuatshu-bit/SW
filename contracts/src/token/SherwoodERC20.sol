// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SherwoodErrors} from "../errors/SherwoodErrors.sol";

/// @title SherwoodERC20
/// @author SHERWOOD Labs
/// @notice A general-purpose ERC-20 token with permit (gasless approvals),
///         pausable transfers, and owner-controlled burning.
///
/// @dev This contract is intentionally independent of the launchpad protocol.
///      It carries no mint function, no factory dependency, and no sale logic.
///      The full token supply is minted once at construction and owned by
///      `initialOwner`. From that point, the supply can only decrease through
///      burning.
///
///      Inheritance order (most-derived last, matching OZ convention):
///        ERC20 → ERC20Burnable → ERC20Pausable → ERC20Permit → Ownable
///
///      C3 linearisation guarantees that ERC20Pausable's `_update` override
///      runs before ERC20's, so the pause check applies to every transfer,
///      mint, and burn path.
contract SherwoodERC20 is ERC20, ERC20Burnable, ERC20Pausable, ERC20Permit, Ownable {
    // ── Constructor ──────────────────────────────────────────────────────────

    /// @notice Deploys a new SherwoodERC20 token and mints the entire supply
    ///         to `initialOwner`.
    /// @param name_         The full token name (e.g. "Sherwood Finance").
    /// @param symbol_       The ticker symbol (e.g. "SHW").
    /// @param totalSupply_  The fixed total supply to mint, in wei (18 decimals).
    ///                      Must be greater than zero.
    /// @param initialOwner  The address that receives ownership and the full
    ///                      minted supply. Cannot be the zero address.
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address initialOwner
    ) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(initialOwner) {
        if (totalSupply_ == 0) revert SherwoodErrors.InvalidTokenAmount();
        _mint(initialOwner, totalSupply_);
    }

    // ── Owner-only state transitions ─────────────────────────────────────────

    /// @notice Pauses all token transfers, burns, and approvals.
    /// @dev Only callable by the contract owner. Reverts if already paused.
    ///      Emits `{Paused}` on success (from OpenZeppelin Pausable).
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes all token transfers, burns, and approvals.
    /// @dev Only callable by the contract owner. Reverts if not paused.
    ///      Emits `{Unpaused}` on success (from OpenZeppelin Pausable).
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Burns `amount` tokens from `account` without requiring an allowance.
    ///         This is an owner-privileged operation intended for compliance use cases
    ///         (e.g. recovering tokens sent to a blacklisted address by court order).
    ///
    /// @dev    Calls the internal `_burn` directly, bypassing the allowance check that
    ///         `burnFrom` would perform. This means the owner can burn any holder's
    ///         tokens unilaterally. Use with extreme caution.
    ///         For self-burning without owner privileges, holders should call
    ///         `burn(amount)` directly.
    ///
    /// @param account The address whose tokens will be burned. Cannot be zero address.
    /// @param amount  The number of tokens to burn, in wei. Must be greater than zero.
    function ownerBurn(address account, uint256 amount) external onlyOwner {
        if (account == address(0)) revert SherwoodErrors.InvalidAddress();
        if (amount == 0) revert SherwoodErrors.InvalidTokenAmount();
        _burn(account, amount);
    }

    // ── Internal overrides ───────────────────────────────────────────────────

    /// @dev Resolves the `_update` diamond conflict between ERC20 and
    ///      ERC20Pausable. ERC20Pausable's override enforces the pause check
    ///      before every state-changing transfer path.
    ///
    ///      This is the single required override when composing ERC20Burnable,
    ///      ERC20Pausable, and ERC20Permit — Solidity requires it to be explicit
    ///      because both ERC20 and ERC20Pausable define `_update`.
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
