/**
 * REST API contract for SHERWOOD.
 * Defines the shape of every endpoint — method, path, request, response,
 * and possible error codes. No implementation lives here.
 *
 * Convention:
 *   - All paths are relative to the API base URL.
 *   - :param denotes a path parameter.
 *   - ?param denotes an optional query parameter.
 *   - Request/Response types reference the shared DTOs and models.
 *   - Error codes are string constants consumed by both Go and TypeScript.
 */

import type { LaunchResponse, WalletResponse, PortfolioResponse, TransactionResponse } from '../dto/response/index.js';
import type { CreateLaunchRequest, UpdateLaunchRequest, BuyTokenRequest, SellTokenRequest } from '../dto/request/index.js';
import type { ApiResponse, PaginatedResponse } from './api.types.js';
import type { User } from '../models/user.model.js';
import type { Activity } from '../models/activity.model.js';
import type { SortOrder } from '../constants/pagination.js';
import type { LaunchStatus } from '../enums/launch-status.js';
import type { Chain } from '../enums/chain.js';

// ─── Auth ─────────────────────────────────────────────────────────────────────

/**
 * POST /auth/nonce
 * Generate a SIWE nonce for the given wallet address.
 *
 * Request:  { address: string }
 * Response: { nonce: string; issuedAt: string }
 * Errors:   INVALID_ADDRESS
 */
export interface AuthNonceEndpoint {
  method: 'POST';
  path: '/auth/nonce';
  request: { address: string };
  response: ApiResponse<{ nonce: string; issuedAt: string }>;
  errors: 'INVALID_ADDRESS';
}

/**
 * POST /auth/verify
 * Verify a SIWE signature and issue a session token.
 *
 * Request:  { message: string; signature: string; address: string }
 * Response: { token: string; user: User }
 * Errors:   INVALID_SIGNATURE | NONCE_EXPIRED | ADDRESS_MISMATCH
 */
export interface AuthVerifyEndpoint {
  method: 'POST';
  path: '/auth/verify';
  request: { message: string; signature: string; address: string };
  response: ApiResponse<{ token: string; user: User }>;
  errors: 'INVALID_SIGNATURE' | 'NONCE_EXPIRED' | 'ADDRESS_MISMATCH';
}

/**
 * POST /auth/logout
 * Revoke the current session token. Requires auth.
 *
 * Request:  (empty)
 * Response: { success: true }
 * Errors:   UNAUTHENTICATED
 */
export interface AuthLogoutEndpoint {
  method: 'POST';
  path: '/auth/logout';
  request: Record<string, never>;
  response: ApiResponse<Record<string, never>>;
  errors: 'UNAUTHENTICATED';
}

// ─── Wallet ───────────────────────────────────────────────────────────────────

/**
 * GET /wallets/:address
 * Retrieve the on-platform profile for a wallet address. Public.
 *
 * Params:   address — EIP-55 checksummed wallet address
 * Response: WalletResponse
 * Errors:   WALLET_NOT_FOUND
 */
export interface GetWalletEndpoint {
  method: 'GET';
  path: '/wallets/:address';
  params: { address: string };
  response: ApiResponse<WalletResponse>;
  errors: 'WALLET_NOT_FOUND';
}

// ─── Launch ───────────────────────────────────────────────────────────────────

/**
 * GET /launches
 * List launches with optional filters and pagination. Public.
 *
 * Query: status?, chain?, sort?, limit?, offset?
 * Response: PaginatedResponse<LaunchResponse>
 * Errors:   INVALID_FILTER
 */
export interface ListLaunchesEndpoint {
  method: 'GET';
  path: '/launches';
  query: {
    status?: LaunchStatus;
    chain?: Chain;
    sort?: SortOrder;
    limit?: number;
    offset?: number;
  };
  response: PaginatedResponse<LaunchResponse>;
  errors: 'INVALID_FILTER';
}

/**
 * GET /launches/:id
 * Retrieve a single launch by internal UUID. Public.
 *
 * Params:   id — UUID
 * Response: LaunchResponse
 * Errors:   LAUNCH_NOT_FOUND
 */
export interface GetLaunchEndpoint {
  method: 'GET';
  path: '/launches/:id';
  params: { id: string };
  response: ApiResponse<LaunchResponse>;
  errors: 'LAUNCH_NOT_FOUND';
}

/**
 * POST /launches
 * Create an off-chain launch draft. Requires auth.
 *
 * Request:  CreateLaunchRequest
 * Response: LaunchResponse (status: Draft)
 * Errors:   UNAUTHENTICATED | VALIDATION_ERROR | MAX_ACTIVE_LAUNCHES_EXCEEDED
 */
export interface CreateLaunchEndpoint {
  method: 'POST';
  path: '/launches';
  request: CreateLaunchRequest;
  response: ApiResponse<LaunchResponse>;
  errors: 'UNAUTHENTICATED' | 'VALIDATION_ERROR' | 'MAX_ACTIVE_LAUNCHES_EXCEEDED';
}

/**
 * PATCH /launches/:id
 * Update off-chain metadata of an existing draft. Requires auth + ownership.
 *
 * Params:   id — UUID
 * Request:  UpdateLaunchRequest (partial)
 * Response: LaunchResponse
 * Errors:   UNAUTHENTICATED | FORBIDDEN | LAUNCH_NOT_FOUND | VALIDATION_ERROR | LAUNCH_NOT_EDITABLE
 */
export interface UpdateLaunchEndpoint {
  method: 'PATCH';
  path: '/launches/:id';
  params: { id: string };
  request: UpdateLaunchRequest;
  response: ApiResponse<LaunchResponse>;
  errors: 'UNAUTHENTICATED' | 'FORBIDDEN' | 'LAUNCH_NOT_FOUND' | 'VALIDATION_ERROR' | 'LAUNCH_NOT_EDITABLE';
}

// ─── Token ────────────────────────────────────────────────────────────────────

/**
 * GET /launches/:id/token
 * Retrieve the ERC-20 token associated with a launch. Public.
 *
 * Params:   id — launch UUID
 * Response: { address, symbol, name, decimals, totalSupply, chain }
 * Errors:   LAUNCH_NOT_FOUND | TOKEN_NOT_DEPLOYED
 */
export interface GetLaunchTokenEndpoint {
  method: 'GET';
  path: '/launches/:id/token';
  params: { id: string };
  response: ApiResponse<{
    address: string;
    symbol: string;
    name: string;
    decimals: 18;
    totalSupply: string;
    chain: Chain;
  }>;
  errors: 'LAUNCH_NOT_FOUND' | 'TOKEN_NOT_DEPLOYED';
}

// ─── Portfolio ────────────────────────────────────────────────────────────────

/**
 * GET /portfolio
 * Retrieve the authenticated user's portfolio (all positions). Requires auth.
 *
 * Response: PortfolioResponse
 * Errors:   UNAUTHENTICATED
 */
export interface GetPortfolioEndpoint {
  method: 'GET';
  path: '/portfolio';
  response: ApiResponse<PortfolioResponse>;
  errors: 'UNAUTHENTICATED';
}

// ─── Transaction ──────────────────────────────────────────────────────────────

/**
 * GET /launches/:id/transactions
 * List all indexed transactions for a launch. Public.
 *
 * Params:   id — launch UUID
 * Query:    type?, limit?, offset?
 * Response: PaginatedResponse<TransactionResponse>
 * Errors:   LAUNCH_NOT_FOUND
 */
export interface ListLaunchTransactionsEndpoint {
  method: 'GET';
  path: '/launches/:id/transactions';
  params: { id: string };
  query: { type?: string; limit?: number; offset?: number };
  response: PaginatedResponse<TransactionResponse>;
  errors: 'LAUNCH_NOT_FOUND';
}

/**
 * GET /transactions/:txHash
 * Retrieve a single transaction by on-chain hash. Public.
 *
 * Params:   txHash — 0x-prefixed 32-byte hex
 * Response: TransactionResponse
 * Errors:   TRANSACTION_NOT_FOUND
 */
export interface GetTransactionEndpoint {
  method: 'GET';
  path: '/transactions/:txHash';
  params: { txHash: string };
  response: ApiResponse<TransactionResponse>;
  errors: 'TRANSACTION_NOT_FOUND';
}

// ─── Activity ─────────────────────────────────────────────────────────────────

/**
 * GET /activity
 * Global activity feed across all launches. Public.
 *
 * Query:    launchId?, walletAddress?, limit?, offset?
 * Response: PaginatedResponse<Activity>
 * Errors:   (none — returns empty list for unknown filters)
 */
export interface ListActivityEndpoint {
  method: 'GET';
  path: '/activity';
  query: { launchId?: string; walletAddress?: string; limit?: number; offset?: number };
  response: PaginatedResponse<Activity>;
  errors: never;
}

// ─── Error code registry ─────────────────────────────────────────────────────

/**
 * Exhaustive union of all error codes returned by the API.
 * The Go backend produces these codes; the TypeScript client consumes them.
 */
export type ApiErrorCode =
  // Auth
  | 'INVALID_ADDRESS'
  | 'INVALID_SIGNATURE'
  | 'NONCE_EXPIRED'
  | 'ADDRESS_MISMATCH'
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  // Resource
  | 'LAUNCH_NOT_FOUND'
  | 'TOKEN_NOT_DEPLOYED'
  | 'TRANSACTION_NOT_FOUND'
  | 'WALLET_NOT_FOUND'
  // Validation
  | 'VALIDATION_ERROR'
  | 'INVALID_FILTER'
  | 'LAUNCH_NOT_EDITABLE'
  | 'MAX_ACTIVE_LAUNCHES_EXCEEDED'
  // Server
  | 'INTERNAL_ERROR'
  | 'SERVICE_UNAVAILABLE';
