import { z } from 'zod';

/**
 * Shared primitive Zod schemas.
 * All validators in this package import from here to avoid duplication.
 */

/** Checksummed EIP-55 Ethereum address (0x + 40 hex chars). */
export const addressSchema = z
  .string()
  .regex(/^0x[0-9a-fA-F]{40}$/, 'Must be a valid EIP-55 checksummed Ethereum address');

/** 0x-prefixed 32-byte transaction hash. */
export const txHashSchema = z
  .string()
  .regex(/^0x[0-9a-fA-F]{64}$/, 'Must be a valid 32-byte transaction hash');

/**
 * A non-negative integer represented as a decimal string.
 * Used for on-chain uint256 values (tokenPrice, softCap, etc.)
 * to avoid JS floating-point precision loss.
 */
export const bigintStringSchema = z
  .string()
  .regex(/^\d+$/, 'Must be a non-negative decimal integer string')
  .refine((val) => BigInt(val) >= 0n, 'Value must be non-negative');

/**
 * Unix timestamp in seconds (uint64 range, post-year-2000 lower bound).
 */
export const unixTimestampSchema = z
  .number()
  .int('Timestamp must be an integer')
  .min(946_684_800, 'Timestamp must be after year 2000')
  .max(4_102_444_800, 'Timestamp must be before year 2100');

/** UUID v4 string. */
export const uuidSchema = z.string().uuid('Must be a valid UUID v4');

/** HTTPS or IPFS URL string. */
export const mediaUrlSchema = z
  .string()
  .url('Must be a valid URL')
  .refine(
    (url) => url.startsWith('https://') || url.startsWith('ipfs://'),
    'URL must use https:// or ipfs:// scheme',
  );
