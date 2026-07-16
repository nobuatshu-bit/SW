import type { Chain } from '../enums/chain.js';

/**
 * An ERC-20 token deployed by SherwoodFactory as part of a launch.
 * One Token maps to exactly one Launch (1-to-1 relationship).
 */
export interface Token {
  /** Internal UUID primary key. */
  readonly id: string;

  /** Foreign key → Launch.id. */
  readonly launchId: string;

  /** Checksummed EIP-55 on-chain contract address. */
  readonly address: string;

  /** Chain the contract is deployed on. */
  readonly chain: Chain;

  /** Full token name, e.g. "Verdant Protocol". */
  readonly name: string;

  /** Uppercase ticker symbol, e.g. "VRD". */
  readonly symbol: string;

  /** Always 18 for SHERWOOD tokens (ERC-20 standard). */
  readonly decimals: 18;

  /**
   * Total token allocation deposited into the LaunchProject contract.
   * Stored as a bigint-compatible decimal string to avoid JS precision loss.
   */
  readonly totalSupply: string;

  /**
   * Checksummed EIP-55 address of the SherwoodFactory contract that minted
   * this token. Used for provenance verification.
   */
  readonly factoryAddress: string;

  /** ISO-8601 UTC timestamp of contract deployment. */
  readonly deployedAt: string;
}
