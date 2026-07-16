import { Chain } from '../enums/chain.js';

/** Base URLs for each chain's block explorer. No trailing slash. */
export const EXPLORER_BASE_URLS: Readonly<Record<Chain, string>> = {
  [Chain.BaseSepolia]: 'https://sepolia.basescan.org',
  [Chain.BaseMainnet]: 'https://basescan.org',
} as const;

/**
 * Builds a full block explorer URL for a transaction hash.
 * @example getExplorerTxUrl(Chain.BaseSepolia, '0xabc...') → 'https://sepolia.basescan.org/tx/0xabc...'
 */
export function getExplorerTxUrl(chain: Chain, txHash: string): string {
  return `${EXPLORER_BASE_URLS[chain]}/tx/${txHash}`;
}

/**
 * Builds a full block explorer URL for a contract or wallet address.
 */
export function getExplorerAddressUrl(chain: Chain, address: string): string {
  return `${EXPLORER_BASE_URLS[chain]}/address/${address}`;
}
