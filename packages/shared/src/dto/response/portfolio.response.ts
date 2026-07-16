import { z } from 'zod';
import { LaunchStatus } from '../../enums/launch-status.js';

/**
 * A single portfolio position: how much a user has invested in one launch.
 */
export const portfolioPositionSchema = z.object({
  launchId: z.string().uuid(),
  launchName: z.string(),
  launchLogoUrl: z.string().url().nullable(),
  contractAddress: z.string().nullable(),
  status: z.nativeEnum(LaunchStatus),

  tokenSymbol: z.string(),
  tokenAddress: z.string().nullable(),

  /** Token amount purchased. Decimal string. */
  tokensPurchased: z.string(),

  /** Token amount already claimed. Decimal string. */
  tokensClaimed: z.string(),

  /** Remaining claimable tokens (tokensPurchased - tokensClaimed). Decimal string. */
  tokensClaimable: z.string(),

  /** Total native-asset contributed. WAD decimal string. */
  totalContributed: z.string(),

  /** Native-asset refundable if the launch is cancelled. WAD decimal string. */
  refundable: z.string(),
});

/**
 * Response body returned from GET /portfolio (authenticated).
 * Aggregates all positions for the requesting user's wallet.
 */
export const portfolioResponseSchema = z.object({
  userId: z.string().uuid(),
  walletAddress: z.string(),

  positions: z.array(portfolioPositionSchema),

  // Aggregate totals across all positions
  /** Sum of all contributions. WAD decimal string. */
  totalContributed: z.string(),

  /** Sum of all claimable token balances across graduated launches. */
  totalClaimablePositions: z.number().int().min(0),

  /** Sum of all refundable contributions across cancelled launches. */
  totalRefundablePositions: z.number().int().min(0),
});

export type PortfolioPosition = z.infer<typeof portfolioPositionSchema>;
export type PortfolioResponse = z.infer<typeof portfolioResponseSchema>;
