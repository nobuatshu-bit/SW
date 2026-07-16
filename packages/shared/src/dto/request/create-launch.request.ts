import { z } from 'zod';
import { LAUNCH_LIMITS } from '../../constants/launch-limits.js';
import { SUPPORTED_SOCIAL_PLATFORMS } from '../../constants/social-links.js';
import { addressSchema, bigintStringSchema, unixTimestampSchema } from '../../validators/primitives.js';

/**
 * Request body for POST /launches — creates an off-chain launch draft.
 * On-chain deployment is a separate step triggered by the frontend after
 * this record is created and approved.
 */
export const createLaunchRequestSchema = z.object({
  // ── Identity ──────────────────────────────────────────────────────────────
  name: z
    .string()
    .min(3, 'Name must be at least 3 characters')
    .max(LAUNCH_LIMITS.maxNameLength, `Name must be at most ${LAUNCH_LIMITS.maxNameLength} characters`)
    .trim(),

  tagline: z
    .string()
    .min(10, 'Tagline must be at least 10 characters')
    .max(LAUNCH_LIMITS.maxTaglineLength, `Tagline must be at most ${LAUNCH_LIMITS.maxTaglineLength} characters`)
    .trim(),

  description: z
    .string()
    .min(50, 'Description must be at least 50 characters')
    .max(LAUNCH_LIMITS.maxDescriptionLength, `Description must be at most ${LAUNCH_LIMITS.maxDescriptionLength} characters`)
    .trim(),

  // ── Media ─────────────────────────────────────────────────────────────────
  logoUrl: z.string().url('Logo must be a valid URL').nullable().optional(),
  bannerUrl: z.string().url('Banner must be a valid URL').nullable().optional(),
  websiteUrl: z.string().url('Website must be a valid URL').nullable().optional(),

  socialLinks: z
    .record(
      z.enum(SUPPORTED_SOCIAL_PLATFORMS),
      z.string().url('Social link must be a valid URL'),
    )
    .optional(),

  // ── Token parameters ──────────────────────────────────────────────────────
  tokenName: z
    .string()
    .min(1, 'Token name is required')
    .max(LAUNCH_LIMITS.maxTokenNameLength)
    .trim(),

  tokenSymbol: z
    .string()
    .min(1, 'Token symbol is required')
    .max(LAUNCH_LIMITS.maxTokenSymbolLength)
    .toUpperCase()
    .trim(),

  // ── Sale parameters (WAD decimal strings, passed directly to the contract) ─
  /** Token price in native asset, WAD decimal string (e.g. "10000000000000000" = 0.01 ETH). */
  tokenPrice: bigintStringSchema,

  /** Total tokens allocated to the sale. Decimal string. */
  saleTokenAllocation: bigintStringSchema,

  /** Minimum raise for graduation. Decimal string. */
  softCap: bigintStringSchema,

  /** Maximum raise cap. Decimal string. */
  maxRaise: bigintStringSchema,

  // ── Schedule ──────────────────────────────────────────────────────────────
  /** Unix timestamp (seconds) when the sale opens. Must be in the future. */
  startTime: unixTimestampSchema,

  /** Unix timestamp (seconds) when the sale closes. Must be after startTime. */
  endTime: unixTimestampSchema,
}).superRefine((val, ctx) => {
  if (val.endTime <= val.startTime) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['endTime'],
      message: 'endTime must be after startTime',
    });
  }
  if (BigInt(val.maxRaise) < BigInt(val.softCap)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['maxRaise'],
      message: 'maxRaise must be greater than or equal to softCap',
    });
  }
});

export type CreateLaunchRequest = z.infer<typeof createLaunchRequestSchema>;
