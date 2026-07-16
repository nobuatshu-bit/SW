// ─── Statistics ──────────────────────────────────────────────────────────────

export const STATS = [
  { label: 'Total Volume', value: '$48.2M', delta: '+12.4%' },
  { label: 'Active Launches', value: '127', delta: '+8' },
  { label: 'Tokens Launched', value: '2,841', delta: '+34' },
  { label: 'Unique Participants', value: '91,600', delta: '+2,300' },
] as const;

// ─── Trending Launches ───────────────────────────────────────────────────────

export type LaunchStatus = 'live' | 'upcoming' | 'graduated';

export interface TrendingLaunch {
  id: string;
  name: string;
  symbol: string;
  description: string;
  status: LaunchStatus;
  raised: string;
  target: string;
  progressPct: number;
  participants: number;
  endsIn: string;
  avatarLabel: string;
}

export const TRENDING_LAUNCHES: TrendingLaunch[] = [
  {
    id: '1',
    name: 'Verdant Protocol',
    symbol: 'VRD',
    description: 'Decentralised carbon credit marketplace enabling transparent on-chain offset trading.',
    status: 'live',
    raised: '184 ETH',
    target: '250 ETH',
    progressPct: 74,
    participants: 1_204,
    endsIn: '2d 14h',
    avatarLabel: 'VP',
  },
  {
    id: '2',
    name: 'Meridian Exchange',
    symbol: 'MRD',
    description: 'Cross-chain AMM with concentrated liquidity and single-sided provisioning.',
    status: 'live',
    raised: '96 ETH',
    target: '200 ETH',
    progressPct: 48,
    participants: 763,
    endsIn: '4d 8h',
    avatarLabel: 'ME',
  },
  {
    id: '3',
    name: 'Solace Finance',
    symbol: 'SLC',
    description: 'Under-collateralised lending powered by on-chain reputation scoring.',
    status: 'upcoming',
    raised: '0 ETH',
    target: '300 ETH',
    progressPct: 0,
    participants: 0,
    endsIn: 'Starts in 1d',
    avatarLabel: 'SF',
  },
  {
    id: '4',
    name: 'Ironwood Vaults',
    symbol: 'IRW',
    description: 'Automated yield optimiser routing capital across Base DeFi protocols.',
    status: 'graduated',
    raised: '500 ETH',
    target: '500 ETH',
    progressPct: 100,
    participants: 3_891,
    endsIn: 'Completed',
    avatarLabel: 'IV',
  },
  {
    id: '5',
    name: 'Nimbus Oracle',
    symbol: 'NBS',
    description: 'Decentralised price feeds with economic slashing for data providers.',
    status: 'live',
    raised: '211 ETH',
    target: '400 ETH',
    progressPct: 53,
    participants: 2_017,
    endsIn: '6d 2h',
    avatarLabel: 'NO',
  },
  {
    id: '6',
    name: 'Ashwood DAO',
    symbol: 'ASH',
    description: 'On-chain grants programme governed by token-weighted community votes.',
    status: 'upcoming',
    raised: '0 ETH',
    target: '150 ETH',
    progressPct: 0,
    participants: 0,
    endsIn: 'Starts in 3d',
    avatarLabel: 'AD',
  },
];

// ─── How It Works ────────────────────────────────────────────────────────────

export interface Step {
  step: string;
  title: string;
  description: string;
}

export const HOW_IT_WORKS_STEPS: Step[] = [
  {
    step: '01',
    title: 'Connect your wallet',
    description:
      'Link any EVM-compatible wallet. SHERWOOD supports WalletConnect, MetaMask, Coinbase Wallet, and more.',
  },
  {
    step: '02',
    title: 'Browse or create a launch',
    description:
      'Explore active token sales filtered by category, raise size, and time remaining — or configure your own in minutes.',
  },
  {
    step: '03',
    title: 'Participate at a fixed price',
    description:
      'Commit native assets at a transparent, fixed token price. Sell back any unclaimed allocation while the sale is live.',
  },
  {
    step: '04',
    title: 'Claim tokens or refund',
    description:
      'Graduated launches release tokens immediately. Cancelled or under-cap launches return your full contribution automatically.',
  },
];

// ─── Features ────────────────────────────────────────────────────────────────

export interface Feature {
  icon: string;
  title: string;
  description: string;
}

export const FEATURES: Feature[] = [
  {
    icon: '⚡',
    title: 'Fixed-price clarity',
    description:
      'No bonding curves, no slippage surprises. Every buyer pays exactly the same price throughout the entire sale window.',
  },
  {
    icon: '🔒',
    title: 'Funds locked until graduation',
    description:
      'Protocol fees and creator proceeds cannot leave a project until it graduates. Buyers retain a full refund right up to that point.',
  },
  {
    icon: '↩️',
    title: 'Mid-sale exit',
    description:
      'Changed your mind? Sell unclaimed allocation back to the launch at the original price while the sale is still live.',
  },
  {
    icon: '🏭',
    title: 'EIP-1167 clone efficiency',
    description:
      'Every launch deploys a gas-minimal proxy rather than a full contract, reducing creation cost by over 90%.',
  },
  {
    icon: '🔑',
    title: 'Non-custodial by design',
    description:
      'Contracts hold no admin keys after deployment. Creator and protocol roles are limited to fee collection and treasury withdrawal.',
  },
  {
    icon: '🌐',
    title: 'Built on Base',
    description:
      'Ethereum security with Base transaction fees. SHERWOOD targets Base Sepolia for testnet and Base mainnet for production.',
  },
];

// ─── Navigation ──────────────────────────────────────────────────────────────

export const NAV_LINKS = [
  { label: 'Launches', href: '#launches' },
  { label: 'How it works', href: '#how-it-works' },
  { label: 'Features', href: '#features' },
] as const;

// ─── Footer ──────────────────────────────────────────────────────────────────

export const FOOTER_LINKS = [
  {
    heading: 'Protocol',
    links: [
      { label: 'Browse launches', href: '#launches' },
      { label: 'Create a launch', href: '#' },
      { label: 'How it works', href: '#how-it-works' },
    ],
  },
  {
    heading: 'Developers',
    links: [
      { label: 'Documentation', href: '#' },
      { label: 'Smart contracts', href: '#' },
      { label: 'GitHub', href: '#' },
    ],
  },
  {
    heading: 'Community',
    links: [
      { label: 'Twitter / X', href: '#' },
      { label: 'Discord', href: '#' },
      { label: 'Blog', href: '#' },
    ],
  },
] as const;
