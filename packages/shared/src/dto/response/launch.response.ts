import { z } from 'zod';
import { LaunchStatus } from '../../enums/launch-status.js';
import { Chain } from '../../enums/chain.js';
import { SUPPORTED_SOCIAL_PLATFORMS } from '../../constants/social-links.js';

/**
 * Response body returned from GET /launches and GET /launches/:id.
 * Combines the off-chain metadata with the indexed on-chain state.
 */
export const launchResponseSchema = z.object({
  id: z.string().uuid(),
  creatorId: z.string().uuid(),
  tokenId: z.string().uuid().nullable(),
  contractAddress: z.string().nullable(),
  chain: z.nativeEnum(Chain),
  status: z.nativeEnum(LaunchStatus),

  // Off-chain metadata
  name: z.string(),
  tagline: z.string(),
  description: z.string(),
  logoUrl: z.string().url().nullable(),
  bannerUrl: z.string().url().nullable(),
  websiteUrl: z.string().url().nullable(),
  socialLinks: z.record(z.enum(SUPPORTED_SOCIAL_PLATFORMS), z.string().url()),

  // On-chain parameters
  tokenPrice: z.string().nullable(),
  saleTokenAllocation: z.string().nullable(),
  softCap: z.string().nullable(),
  maxRaise: z.string().nullable(),
  totalRaised: z.string().nullable(),
  protocolFeeBps: z.number().int().nullable(),
  startTime: z.number().int().nullable(),
  endTime: z.number().int().nullable(),

  // Derived / computed fields populated by the backend read layer
  /** Progress percentage 0–100 (totalRaised / maxRaise × 100). Null until live. */
  progressPct: z.number().min(0).max(100).nullable(),

  /** Number of unique wallet addresses that have bought tokens. */
  participantCount: z.number().int().min(0),

  // Timestamps
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
});

export type LaunchResponse = z.infer<typeof launchResponseSchema>;
