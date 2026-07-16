/**
 * Generic HTTP API envelope types.
 * Every SHERWOOD REST endpoint wraps its payload in one of these shapes.
 */

/** Success envelope for a single resource. */
export interface ApiResponse<T> {
  readonly success: true;
  readonly data: T;
}

/** Success envelope for a paginated resource list. */
export interface PaginatedResponse<T> {
  readonly success: true;
  readonly data: readonly T[];
  readonly pagination: {
    readonly total: number;
    readonly limit: number;
    readonly offset: number;
    readonly hasMore: boolean;
  };
}

/** Error envelope returned for all 4xx and 5xx responses. */
export interface ApiErrorResponse {
  readonly success: false;
  readonly error: {
    /** Machine-readable error code, e.g. "LAUNCH_NOT_FOUND". */
    readonly code: string;
    /** Human-readable message safe to display in the UI. */
    readonly message: string;
    /** Field-level validation errors, present on 422 responses. */
    readonly fieldErrors?: Readonly<Record<string, readonly string[]>>;
  };
}

/** Union of all possible API responses. */
export type ApiResult<T> = ApiResponse<T> | ApiErrorResponse;
