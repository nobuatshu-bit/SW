import { z } from 'zod';
import { Chain } from '../enums/chain.js';
import { TransactionType } from '../enums/transaction-type.js';
import { addressSchema, txHashSchema, bigintStringSchema, uuidSchema } from './primitives.js';

/**
 * Validates a transaction payload submitted by the event indexer when
 * persisting an indexed on-chain event to the database.
 * Not called by end users directly.
 */
export const indexTransactionSchema = z.object({
  launchId:       uuidSchema,
  walletAddress:  addressSchema,
  chain:          z.nativeEnum(Chain),
  txHash:         txHashSchema,
  blockNumber:    z.number().int().positive(),
  blockTimestamp: z.number().int().positive(),
  type:           z.nativeEnum(TransactionType),
  nativeAmount:   bigintStringSchema.nullable(),
  tokenAmount:    bigintStringSchema.nullable(),
});

export type IndexTransactionInput = z.infer<typeof indexTransactionSchema>;
