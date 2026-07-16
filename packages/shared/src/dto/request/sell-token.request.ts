import { z } from 'zod';
import { bigintStringSchema } from '../../validators/primitives.js';

/**
 * Request body for POST /launches/:id/sell — records a sell transaction
 * submitted by the frontend after the user signs and broadcasts the tx.
 *
 * The backend validates the transaction hash on-chain before persisting.
 */
export const sellTokenRequestSchema = z.object({
  /** Canonical 0x-prefixed transaction hash of the confirmed sell tx. */
  txHash: z
    .string()
    .regex(/^0x[0-9a-fA-F]{64}$/, 'txHash must be a valid 32-byte hex hash'),

  /**
   * Token amount sold back, as a decimal string.
   * Must match the tokenAmount argument in the on-chain sell() call.
   */
  tokenAmount: bigintStringSchema,

  /**
   * Native-asset refund received, as a WAD decimal string.
   * Verified against the TokensSold event log.
   */
  nativeAmount: bigintStringSchema,
});

export type SellTokenRequest = z.infer<typeof sellTokenRequestSchema>;
