import { z } from 'zod';
import { Chain } from '../../enums/chain.js';
import { WalletType } from '../../enums/wallet-type.js';

/**
 * Response body returned from GET /wallets/:address and included in the
 * auth session payload after a successful SIWE sign-in.
 */
export const walletResponseSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().uuid(),
  address: z.string(),
  chain: z.nativeEnum(Chain),
  walletType: z.nativeEnum(WalletType),
  isPrimary: z.boolean(),
  connectedAt: z.string().datetime(),
  lastSeenAt: z.string().datetime(),
});

export type WalletResponse = z.infer<typeof walletResponseSchema>;
