import type { WalletType } from '../enums/wallet-type.js';

/**
 * A SHERWOOD platform user identified by their primary wallet address.
 * Authentication is wallet-signature based (SIWE); there is no password.
 */
export interface User {
  /** Internal UUID primary key. */
  readonly id: string;

  /**
   * Checksummed EIP-55 primary wallet address.
   * Uniqueness constraint in the database.
   */
  readonly address: string;

  /** Display name chosen by the user. Nullable until set. */
  displayName: string | null;

  /** Avatar URL (IPFS or https). Nullable until set. */
  avatarUrl: string | null;

  /** ISO-8601 UTC timestamp of account creation. */
  readonly createdAt: string;

  /** ISO-8601 UTC timestamp of last profile update. */
  updatedAt: string;

  /** Soft-delete flag. Deleted users retain their address for audit purposes. */
  readonly isDeleted: boolean;
}
