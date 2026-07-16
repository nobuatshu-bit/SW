import { Chain } from '../enums/chain.js';

/**
 * Deployed contract addresses for each chain.
 *
 * ⚠️  These are placeholders. Replace with real addresses after deployment.
 *     The values are typed as `0x${string}` to be compatible with viem/wagmi.
 */
export type HexAddress = `0x${string}`;

export interface ContractAddresses {
  /** SherwoodFactory proxy/implementation address. */
  readonly sherwoodFactory: HexAddress;

  /** LaunchProject implementation address (used by the factory for EIP-1167 clones). */
  readonly launchProjectImplementation: HexAddress;
}

export const CONTRACT_ADDRESSES: Readonly<Record<Chain, ContractAddresses>> = {
  [Chain.BaseSepolia]: {
    sherwoodFactory:             '0x0000000000000000000000000000000000000000',
    launchProjectImplementation: '0x0000000000000000000000000000000000000000',
  },
  [Chain.BaseMainnet]: {
    sherwoodFactory:             '0x0000000000000000000000000000000000000000',
    launchProjectImplementation: '0x0000000000000000000000000000000000000000',
  },
} as const;
