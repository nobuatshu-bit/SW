/**
 * Default and maximum pagination values applied to all list endpoints.
 * Consistent defaults prevent accidental full-table reads.
 */
export const PAGINATION = {
  /** Default number of items per page when ?limit is omitted. */
  defaultLimit: 20,

  /** Maximum items a client may request in a single page. */
  maxLimit: 100,

  /** Default sort order for list endpoints. */
  defaultSortOrder: 'desc' as const,
} as const;

export type SortOrder = typeof PAGINATION.defaultSortOrder | 'asc';
