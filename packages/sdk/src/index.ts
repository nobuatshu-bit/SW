import { healthResponseSchema, type HealthResponse } from '@sherwood/shared';
import type { Address } from 'viem';

export interface SherwoodClientOptions {
  baseUrl: string;
  fetch?: typeof globalThis.fetch;
}

export class SherwoodClient {
  private readonly fetcher: typeof globalThis.fetch;

  public constructor(private readonly options: SherwoodClientOptions) {
    this.fetcher = options.fetch ?? globalThis.fetch;
  }

  public async health(): Promise<HealthResponse> {
    const response = await this.fetcher(new URL('/health', this.options.baseUrl));
    if (!response.ok) {
      throw new Error(`Health request failed with status ${response.status}`);
    }

    return healthResponseSchema.parse(await response.json());
  }
}

export const counterAbi = [
  {
    type: 'function',
    name: 'number',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'increment',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
] as const;

export type ContractAddresses = {
  counter?: Address;
};
