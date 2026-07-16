import type { Chain } from '../enums/chain.js';
import type { TransactionType } from '../enums/transaction-type.js';

/**
 * A single on-chain transaction indexed by the SHERWOOD event indexer.
 * Immutable after creation — blockchain history cannot be changed.
 */
export interface Transaction {
  /** Internal UUID primary key. */
  readonly id: string;

  /** Foreign key → Launch.id. */
  readonly launchId: string;

  /** Foreign key → User.id. Null if the wallet address has no registered user. */
  readonly userId: string | null;

  /** Checksummed EIP-55 wallet address that signed the transaction. */
  readonly walletAddress: string;

  /** Chain the transaction was confirmed on. */
  readonly chain: Chain;

  /** Canonical 0x-prefixed transaction hash. */
  readonly txHash: string;

  /** Block number the transaction was confirmed in. */
  readonly blockNumber: number;

  /** Unix timestamp (seconds) of the block. */
  readonly blockTimestamp: number;

  /** Type of protocol action this transaction represents. */
  readonly type: TransactionType;

  /**
   * Native-asset value involved (ETH paid, refunded, or withdrawn).
   * Decimal string. Null for non-value transactions (e.g. Claim of tokens).
   */
  readonly nativeAmount: string | null;

  /**
   * Token amount involved.
   * Decimal string. Null for non-token transactions (e.g. treasury withdrawal).
   */
  readonly tokenAmount: string | null;

  /** ISO-8601 UTC timestamp when this record was indexed. */
  readonly indexedAt: string;
}
