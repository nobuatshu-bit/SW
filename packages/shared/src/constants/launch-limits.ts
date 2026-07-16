/**
 * Hard limits on launch creation parameters.
 * These are enforced by both the Zod validators (off-chain) and the contract
 * (LaunchConstants.sol) on-chain. Keep them in sync.
 */
export const LAUNCH_LIMITS = {
  // Copy constraints
  maxNameLength:        80,
  maxTaglineLength:     160,
  maxDescriptionLength: 10_000,
  maxTokenNameLength:   50,
  maxTokenSymbolLength: 10,

  // Sale window
  /** Minimum sale duration in seconds (24 hours). */
  minSaleDurationSeconds: 24 * 60 * 60,

  /** Maximum sale duration in seconds (90 days). */
  maxSaleDurationSeconds: 90 * 24 * 60 * 60,

  /** Maximum number of active launches per creator at any one time. */
  maxActiveLaunchesPerCreator: 3,

  /**
   * Maximum protocol fee in basis points (500 = 5%).
   * Must match LaunchConstants.MAX_PROTOCOL_FEE_BPS in the contract.
   */
  maxProtocolFeeBps: 500,

  /** Minimum token price: 0.000001 ETH expressed as a WAD string. */
  minTokenPriceWad: '1000000000000' as const,
} as const;
