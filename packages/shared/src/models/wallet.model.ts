import type { Chain } from '../enums/chain.js';
import type { WalletType } from '../enums/wallet-type.js';

/**
 * A wallet connected to the SHERWOOD platform.
 * A single user may have multiple wallets across multiple chains.
 */
export interface Wallet {
  /** Internal UUID primary key. */
  readonly id: string;

  /** Foreign key → User.id. */
  readonly userId: string;

  /** Checksummed EIP-55 wallet address. */
  readonly address: string;

  /** Chain this wallet entry is associated with. */
  readonly chain: Chain;

  /** Connection mechanism used to link the wallet. */
  walletType: WalletType;

  /** Whether this is the user's primary / currently active wallet. */
  isPrimary: boolean;

  /** ISO-8601 UTC timestamp of first connection. */
  readonly connectedAt: string;

  /** ISO-8601 UTC timestamp of last activity on this wallet. */
  lastSeenAt: string;
}
