/**
 * Protocol fee configuration.
 * These values reflect the current deployment — update when governance changes them.
 */
export const FEE_CONFIG = {
  /**
   * Default protocol fee in basis points applied to new launches.
   * 250 bps = 2.5%
   */
  defaultProtocolFeeBps: 250,

  /** BPS denominator. Always 10_000 (matching the Solidity constant). */
  bpsDenominator: 10_000,

  /**
   * Computes the protocol fee amount from a raise total.
   * Both arguments must be bigints to avoid floating-point precision loss.
   *
   * @example computeProtocolFee(100n * 10n**18n, 250) → 2.5 ETH in wei
   */
  computeProtocolFee(totalRaisedWei: bigint, feeBps: number): bigint {
    return (totalRaisedWei * BigInt(feeBps)) / BigInt(FEE_CONFIG.bpsDenominator);
  },
} as const;
