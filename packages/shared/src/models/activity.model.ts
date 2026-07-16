import type { TransactionType } from '../enums/transaction-type.js';

/**
 * A denormalised activity feed item, suitable for display in the UI without
 * further joins. Derived from Transaction records by the backend read layer.
 *
 * This is a read model — it is never written to directly.
 */
export interface Activity {
  /** Internal UUID primary key (same as Transaction.id). */
  readonly id: string;

  /** Foreign key → Launch.id. */
  readonly launchId: string;

  /** Launch name at time of activity (denormalised for display). */
  readonly launchName: string;

  /** Foreign key → User.id. Null for unregistered wallets. */
  readonly userId: string | null;

  /** Display name of the actor. Falls back to a truncated wallet address. */
  readonly actorLabel: string;

  /** Checksummed EIP-55 wallet address. */
  readonly walletAddress: string;

  /** Type of action performed. */
  readonly type: TransactionType;

  /**
   * Human-readable summary of the action, e.g. "Bought 1,200 VRD for 0.05 ETH".
   * Formatted by the backend — ready to render.
   */
  readonly summary: string;

  /** Canonical 0x-prefixed transaction hash for block explorer links. */
  readonly txHash: string;

  /** Unix timestamp (seconds) of the block. Used for relative time display. */
  readonly blockTimestamp: number;

  /** ISO-8601 UTC timestamp when this record was indexed. */
  readonly indexedAt: string;
}
