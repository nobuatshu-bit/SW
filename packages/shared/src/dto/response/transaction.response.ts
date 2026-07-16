import { z } from 'zod';
import { Chain } from '../../enums/chain.js';
import { TransactionType } from '../../enums/transaction-type.js';

/**
 * Response body returned from GET /transactions and GET /transactions/:id.
 * Represents a single indexed on-chain event.
 */
export const transactionResponseSchema = z.object({
  id: z.string().uuid(),
  launchId: z.string().uuid(),
  userId: z.string().uuid().nullable(),
  walletAddress: z.string(),
  chain: z.nativeEnum(Chain),
  txHash: z.string(),
  blockNumber: z.number().int().positive(),
  blockTimestamp: z.number().int().positive(),
  type: z.nativeEnum(TransactionType),
  nativeAmount: z.string().nullable(),
  tokenAmount: z.string().nullable(),
  indexedAt: z.string().datetime(),

  // Enriched fields populated by the read layer (not stored on the transaction row)
  /** Human-readable label for the type, e.g. "Buy" / "Sell" / "Claim". */
  typeLabel: z.string(),

  /** Full block explorer URL for this transaction. */
  explorerUrl: z.string().url(),
});

export type TransactionResponse = z.infer<typeof transactionResponseSchema>;
