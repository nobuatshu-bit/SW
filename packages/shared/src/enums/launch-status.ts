/**
 * Mirrors the on-chain ProjectState enum in LaunchTypes.sol and maps the
 * additional off-chain lifecycle states that only exist in the backend DB.
 *
 * On-chain states:   Pending | Live | Graduated | Cancelled
 * Off-chain states:  Draft | PendingReview | Upcoming (alias for Pending)
 *                    Completed (alias for Graduated)
 *
 * The string values are persisted in Postgres — never change them.
 */
export enum LaunchStatus {
  /** Created by the creator but not yet submitted for review. Off-chain only. */
  Draft = 'draft',

  /** Submitted and awaiting moderation before going on-chain. Off-chain only. */
  PendingReview = 'pending_review',

  /** Approved and deployed on-chain; waiting for startTime. Maps to Pending on-chain. */
  Upcoming = 'upcoming',

  /** Sale window is open; buyers can buy/sell. Maps to Live on-chain. */
  Live = 'live',

  /** Sale ended and softCap was met; tokens claimable. Maps to Graduated on-chain. */
  Completed = 'completed',

  /** Sale was cancelled by creator or failed to meet softCap. Maps to Cancelled on-chain. */
  Cancelled = 'cancelled',
}
