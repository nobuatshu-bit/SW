import { z } from 'zod';
import { LAUNCH_LIMITS } from '../constants/launch-limits.js';

/**
 * Validates token name and symbol for use in both the create-launch form
 * and the backend indexer ingestion path.
 * Extracted as a standalone schema so it can be composed into larger schemas
 * without duplication.
 */
export const tokenIdentitySchema = z.object({
  name: z
    .string()
    .min(1, 'Token name is required')
    .max(LAUNCH_LIMITS.maxTokenNameLength, `Token name must be at most ${LAUNCH_LIMITS.maxTokenNameLength} characters`)
    .trim(),

  symbol: z
    .string()
    .min(1, 'Token symbol is required')
    .max(LAUNCH_LIMITS.maxTokenSymbolLength, `Token symbol must be at most ${LAUNCH_LIMITS.maxTokenSymbolLength} characters`)
    .regex(/^[A-Z0-9]+$/, 'Token symbol must contain only uppercase letters and digits')
    .trim(),
});

export type TokenIdentityInput = z.infer<typeof tokenIdentitySchema>;
