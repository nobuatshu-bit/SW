import { z } from 'zod';
import { LAUNCH_LIMITS } from '../../constants/launch-limits.js';
import { addressSchema } from '../../validators/primitives.js';
import { Chain } from '../../enums/chain.js';

/**
 * Request body for POST /tokens — registers an on-chain token deployment
 * into the backend database after the factory emits a ProjectCreated event.
 * In practice this is called by the event indexer, not the user directly.
 */
export const createTokenRequestSchema = z.object({
  launchId: z.string().uuid('launchId must be a valid UUID'),

  /** Checksummed EIP-55 contract address of the deployed ERC-20. */
  address: addressSchema,

  chain: z.nativeEnum(Chain),

  name: z
    .string()
    .min(1)
    .max(LAUNCH_LIMITS.maxTokenNameLength)
    .trim(),

  symbol: z
    .string()
    .min(1)
    .max(LAUNCH_LIMITS.maxTokenSymbolLength)
    .toUpperCase()
    .trim(),

  /** Total supply as decimal string (always 18 decimals for SHERWOOD tokens). */
  totalSupply: z.string().regex(/^\d+$/, 'totalSupply must be a decimal integer string'),

  /** Checksummed EIP-55 address of the SherwoodFactory that deployed this token. */
  factoryAddress: addressSchema,

  /** ISO-8601 UTC timestamp of block in which the contract was deployed. */
  deployedAt: z.string().datetime(),
});

export type CreateTokenRequest = z.infer<typeof createTokenRequestSchema>;
