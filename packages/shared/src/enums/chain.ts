/**
 * EVM chains supported by SHERWOOD.
 * The numeric values are canonical chain IDs used by wagmi/viem and stored in
 * the database — never change them.
 */
export enum Chain {
  /** Base Sepolia testnet. Primary development and QA environment. */
  BaseSepolia = 84532,

  /** Base mainnet. Production environment. */
  BaseMainnet = 8453,
}
