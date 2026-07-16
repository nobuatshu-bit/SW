import { Chain } from '../enums/chain.js';

/**
 * Metadata record for each supported EVM chain.
 * Kept in constants (not enums) because the shape is richer than a scalar.
 */
export interface ChainConfig {
  readonly chainId: number;
  readonly name: string;
  readonly shortName: string;
  readonly nativeCurrency: {
    readonly name: string;
    readonly symbol: string;
    readonly decimals: 18;
  };
  readonly rpcUrl: string;
  readonly isTestnet: boolean;
}

export const CHAIN_CONFIGS: Readonly<Record<Chain, ChainConfig>> = {
  [Chain.BaseSepolia]: {
    chainId: 84532,
    name: 'Base Sepolia',
    shortName: 'base-sepolia',
    nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
    rpcUrl: 'https://sepolia.base.org',
    isTestnet: true,
  },
  [Chain.BaseMainnet]: {
    chainId: 8453,
    name: 'Base',
    shortName: 'base',
    nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
    rpcUrl: 'https://mainnet.base.org',
    isTestnet: false,
  },
} as const;

/** Chains available in the current environment. Testnet excluded from production. */
export const SUPPORTED_CHAINS: readonly Chain[] = [
  Chain.BaseSepolia,
  Chain.BaseMainnet,
] as const;
