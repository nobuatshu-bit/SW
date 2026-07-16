/**
 * Platform slugs accepted in the socialLinks map on a Launch.
 * Used as both the Zod enum and the key type for the record.
 */
export const SUPPORTED_SOCIAL_PLATFORMS = [
  'twitter',
  'discord',
  'telegram',
  'github',
  'medium',
  'linkedin',
  'youtube',
  'farcaster',
] as const satisfies readonly string[];

export type SocialPlatform = (typeof SUPPORTED_SOCIAL_PLATFORMS)[number];

/** Human-readable labels for display in the UI. */
export const SOCIAL_PLATFORM_LABELS: Readonly<Record<SocialPlatform, string>> = {
  twitter:   'X / Twitter',
  discord:   'Discord',
  telegram:  'Telegram',
  github:    'GitHub',
  medium:    'Medium',
  linkedin:  'LinkedIn',
  youtube:   'YouTube',
  farcaster: 'Farcaster',
} as const;
