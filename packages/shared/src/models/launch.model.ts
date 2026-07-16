import type { Chain } from '../enums/chain.js';
import type { LaunchStatus } from '../enums/launch-status.js';

/**
 * A SHERWOOD token launch — the central aggregate of the protocol.
 * Combines off-chain metadata (description, images) with on-chain parameters
 * (tokenPrice, softCap, maxRaise) indexed from the blockchain.
 */
export interface Launch {
  /** Internal UUID primary key. */
  readonly id: string;

  /** Foreign key → User.id (the creator). */
  readonly creatorId: string;

  /** Foreign key → Token.id. Null until the contract is deployed. */
  tokenId: string | null;

  /** Checksummed EIP-55 address of the LaunchProject clone contract. Null until deployed. */
  contractAddress: string | null;

  /** Chain this launch is deployed on. */
  readonly chain: Chain;

  /** Current lifecycle state. */
  status: LaunchStatus;

  // ── Off-chain metadata ────────────────────────────────────────────────────

  /** Short human-readable project name. Max 80 chars. */
  name: string;

  /** Tagline shown in listings. Max 160 chars. */
  tagline: string;

  /** Full markdown project description. */
  description: string;

  /** Project logo/avatar URL (IPFS or https). */
  logoUrl: string | null;

  /** Project banner image URL. */
  bannerUrl: string | null;

  /** Project website URL. */
  websiteUrl: string | null;

  /** Social link map. Keys are platform slugs (twitter, discord, telegram, github). */
  socialLinks: Record<string, string>;

  // ── On-chain parameters (indexed from events) ─────────────────────────────

  /**
   * Fixed token price in native asset (ETH), stored as a WAD decimal string
   * (1e18 = 1 ETH) to avoid JS precision loss.
   */
  tokenPrice: string | null;

  /**
   * Total token allocation allocated to the sale. Decimal string.
   */
  saleTokenAllocation: string | null;

  /**
   * Minimum native-asset raise required for graduation. Decimal string.
   */
  softCap: string | null;

  /**
   * Maximum native-asset raise cap. Decimal string.
   */
  maxRaise: string | null;

  /**
   * Total native-asset raised so far. Updated by event indexer. Decimal string.
   */
  totalRaised: string | null;

  /** Protocol fee in basis points captured at launch creation. */
  protocolFeeBps: number | null;

  /** Unix timestamp (seconds) when the sale starts. */
  startTime: number | null;

  /** Unix timestamp (seconds) when the sale ends. */
  endTime: number | null;

  /** ISO-8601 UTC timestamp of record creation (off-chain). */
  readonly createdAt: string;

  /** ISO-8601 UTC timestamp of last off-chain or indexed update. */
  updatedAt: string;
}
