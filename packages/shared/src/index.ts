/**
 * @sherwood/shared — public API
 *
 * Import from sub-paths for tree-shaking in application code:
 *   import { LaunchStatus } from '@sherwood/shared/enums'
 *   import type { Launch } from '@sherwood/shared/models'
 *
 * Import from the root for convenience in small scripts and tests.
 */

// ── Preserved originals ───────────────────────────────────────────────────────
import { z } from 'zod';

export const environmentSchema = z.enum(['development', 'test', 'production']);
export type Environment = z.infer<typeof environmentSchema>;

export const healthResponseSchema = z.object({
  status: z.literal('ok'),
  service: z.string(),
  timestamp: z.string().datetime(),
  checks: z.object({
    postgres: z.boolean(),
    redis:    z.boolean(),
  }).optional(),
});
export type HealthResponse = z.infer<typeof healthResponseSchema>;

export function isDefined<T>(value: T | null | undefined): value is T {
  return value !== null && value !== undefined;
}

// ── Enums ─────────────────────────────────────────────────────────────────────
export { LaunchStatus }    from './enums/launch-status.js';
export { Chain }           from './enums/chain.js';
export { TransactionType } from './enums/transaction-type.js';
export { WalletType }      from './enums/wallet-type.js';

// ── Domain models (type-only — no runtime overhead) ───────────────────────────
export type { User }        from './models/user.model.js';
export type { Wallet }      from './models/wallet.model.js';
export type { Token }       from './models/token.model.js';
export type { Launch }      from './models/launch.model.js';
export type { Transaction } from './models/transaction.model.js';
export type { Activity }    from './models/activity.model.js';

// ── Request DTOs ──────────────────────────────────────────────────────────────
export { createLaunchRequestSchema,  type CreateLaunchRequest  } from './dto/request/create-launch.request.js';
export { updateLaunchRequestSchema,  type UpdateLaunchRequest  } from './dto/request/update-launch.request.js';
export { createTokenRequestSchema,   type CreateTokenRequest   } from './dto/request/create-token.request.js';
export { buyTokenRequestSchema,      type BuyTokenRequest      } from './dto/request/buy-token.request.js';
export { sellTokenRequestSchema,     type SellTokenRequest     } from './dto/request/sell-token.request.js';

// ── Response DTOs ─────────────────────────────────────────────────────────────
export { launchResponseSchema,      type LaunchResponse      } from './dto/response/launch.response.js';
export { walletResponseSchema,      type WalletResponse      } from './dto/response/wallet.response.js';
export {
  portfolioResponseSchema,
  portfolioPositionSchema,
  type PortfolioResponse,
  type PortfolioPosition,
} from './dto/response/portfolio.response.js';
export { transactionResponseSchema, type TransactionResponse } from './dto/response/transaction.response.js';

// ── Constants ─────────────────────────────────────────────────────────────────
export { CHAIN_CONFIGS, SUPPORTED_CHAINS, type ChainConfig }       from './constants/chains.js';
export { EXPLORER_BASE_URLS, getExplorerTxUrl, getExplorerAddressUrl } from './constants/explorers.js';
export { CONTRACT_ADDRESSES, type ContractAddresses, type HexAddress } from './constants/contracts.js';
export { PAGINATION, type SortOrder }                               from './constants/pagination.js';
export { LAUNCH_LIMITS }                                            from './constants/launch-limits.js';
export { FEE_CONFIG }                                               from './constants/fees.js';
export {
  SUPPORTED_IMAGE_MIME_TYPES,
  SUPPORTED_IMAGE_EXTENSIONS,
  IMAGE_SIZE_LIMITS,
  type SupportedImageMimeType,
} from './constants/image-formats.js';
export {
  SUPPORTED_SOCIAL_PLATFORMS,
  SOCIAL_PLATFORM_LABELS,
  type SocialPlatform,
} from './constants/social-links.js';

// ── Validators ────────────────────────────────────────────────────────────────
export {
  addressSchema,
  txHashSchema,
  bigintStringSchema,
  unixTimestampSchema,
  uuidSchema,
  mediaUrlSchema,
} from './validators/primitives.js';
export {
  walletConnectSchema,
  siwePayloadSchema,
  type WalletConnectInput,
  type SiwePayloadInput,
} from './validators/wallet.validator.js';
export {
  updateUserProfileSchema,
  type UpdateUserProfileInput,
} from './validators/user.validator.js';
export {
  tokenIdentitySchema,
  type TokenIdentityInput,
} from './validators/token.validator.js';
export {
  launchSaleParamsSchema,
  launchMetadataSchema,
  type LaunchSaleParamsInput,
  type LaunchMetadataInput,
} from './validators/launch.validator.js';
export {
  indexTransactionSchema,
  type IndexTransactionInput,
} from './validators/transaction.validator.js';

// ── API types ─────────────────────────────────────────────────────────────────
export type {
  ApiResponse,
  PaginatedResponse,
  ApiErrorResponse,
  ApiResult,
} from './types/api.types.js';
export type {
  ApiErrorCode,
  AuthNonceEndpoint,
  AuthVerifyEndpoint,
  AuthLogoutEndpoint,
  GetWalletEndpoint,
  ListLaunchesEndpoint,
  GetLaunchEndpoint,
  CreateLaunchEndpoint,
  UpdateLaunchEndpoint,
  GetLaunchTokenEndpoint,
  GetPortfolioEndpoint,
  ListLaunchTransactionsEndpoint,
  GetTransactionEndpoint,
  ListActivityEndpoint,
} from './types/api-contract.types.js';
