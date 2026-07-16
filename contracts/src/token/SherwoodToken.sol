// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SherwoodErrors} from "../errors/SherwoodErrors.sol";

/// @title  SherwoodToken
/// @notice ERC-20 launch token whose supply can only be minted once by the
///         deploying factory, immediately after deployment.
///
/// @dev    Design rationale
///         ──────────────────
///         Ownership is assigned to the launch creator, giving them control over
///         off-chain metadata and the ability to burn their own tokens via the
///         inherited ERC20Burnable interface. Mint authority is permanently bound
///         to the `factory` address set at construction — no other address can
///         ever mint tokens.
///
///         This contract includes ERC20Permit (EIP-2612) for gasless approvals,
///         which is relevant for chains (including Robinhood Chain) where users
///         may prefer permit-based flows to avoid approve+transfer round trips.
///
///         Supply cap
///         ──────────
///         There is no protocol-level supply cap beyond what the factory mints
///         at creation time. Because only the factory can call mint() and the
///         factory calls it exactly once (inside createLaunch), the circulating
///         supply equals saleTokenAllocation for the lifetime of the token.
contract SherwoodToken is ERC20, ERC20Burnable, ERC20Permit, Ownable {

    // ── Immutables ────────────────────────────────────────────────────────────

    /// @notice Factory address permanently authorised to mint tokens.
    ///         Set once in the constructor; immutable thereafter.
    address public immutable factory;

    // ── Modifiers ─────────────────────────────────────────────────────────────

    modifier onlyFactory() {
        if (msg.sender != factory) revert SherwoodErrors.UnauthorizedFactory();
        _;
    }

    // ── Constructor ───────────────────────────────────────────────────────────

    /// @notice Deploys the token and binds it to its factory and owner.
    /// @dev    No tokens are minted here; the factory mints exactly once into the
    ///         LaunchProject clone immediately after calling this constructor.
    /// @param  name_         ERC-20 token name (e.g. "My Project Token").
    /// @param  symbol_       ERC-20 token symbol (e.g. "MPT").
    /// @param  factory_      Address permanently authorised to call mint().
    ///                       Typically the deploying SherwoodFactory instance.
    /// @param  initialOwner  Address that receives ERC-20 ownership (the creator).
    ///                       Cannot be the zero address.
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

    // ── Mint (factory only) ───────────────────────────────────────────────────

    /// @notice Mints `amount` tokens to `to`.
    ///         Only the immutable `factory` address may call this function.
    /// @dev    The factory calls this exactly once per launch (inside createLaunch)
    ///         to seed the LaunchProject clone with the full sale allocation.
    ///         Reverts if `to` is the zero address or if `amount` is zero.
    /// @param  to      Recipient address. Must not be the zero address.
    /// @param  amount  Number of tokens to mint. Must be greater than zero.
    function mint(address to, uint256 amount) external onlyFactory {
        if (to == address(0)) revert SherwoodErrors.InvalidAddress();
        if (amount == 0) revert SherwoodErrors.InvalidTokenAmount();
        _mint(to, amount);
    }
}
