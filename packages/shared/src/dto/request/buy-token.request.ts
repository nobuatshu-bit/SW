import { z } from 'zod';
import { bigintStringSchema } from '../../validators/primitives.js';

/**
 * Request body for POST /launches/:id/buy — records a buy transaction
 * submitted by the frontend after the user signs and broadcasts the tx.
 *
 * The backend validates the transaction hash on-chain before persisting.
 */
export const buyTokenRequestSchema = z.object({
  /** Canonical 0x-prefixed transaction hash of the confirmed buy tx. */
  txHash: z
    .string()
    .regex(/^0x[0-9a-fA-F]{64}$/, 'txHash must be a valid 32-byte hex hash'),

  /**
   * Native-asset amount paid, as a WAD decimal string.
   * Must match msg.value in the on-chain transaction exactly.
   */
  nativeAmount: bigintStringSchema,

  /**
   * Token amount received, as a decimal string.
   * Verified against the TokensBought event log.
   */
  tokenAmount: bigintStringSchema,
});

export type BuyTokenRequest = z.infer<typeof buyTokenRequestSchema>;
