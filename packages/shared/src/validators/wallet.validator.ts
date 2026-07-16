import { z } from 'zod';
import { Chain } from '../enums/chain.js';
import { WalletType } from '../enums/wallet-type.js';
import { addressSchema } from './primitives.js';

/**
 * Validates a wallet connection payload — submitted by the frontend when
 * the user connects a wallet (before SIWE authentication).
 */
export const walletConnectSchema = z.object({
  address:    addressSchema,
  chain:      z.nativeEnum(Chain),
  walletType: z.nativeEnum(WalletType),
});

/**
 * Validates a SIWE (Sign-In with Ethereum) message payload.
 * The backend verifies the signature independently; this schema validates
 * the shape before that check runs.
 */
export const siwePayloadSchema = z.object({
  /** The EIP-4361 plaintext message that was signed. */
  message: z.string().min(1, 'SIWE message is required'),

  /** The wallet's signature over the message (0x-prefixed hex). */
  signature: z
    .string()
    .regex(/^0x[0-9a-fA-F]{130}$/, 'Signature must be a valid 65-byte hex string'),

  /** The wallet address that signed (used for address recovery cross-check). */
  address: addressSchema,
});

export type WalletConnectInput = z.infer<typeof walletConnectSchema>;
export type SiwePayloadInput = z.infer<typeof siwePayloadSchema>;
