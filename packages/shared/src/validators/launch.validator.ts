import { z } from 'zod';
import { LAUNCH_LIMITS } from '../constants/launch-limits.js';
import { SUPPORTED_SOCIAL_PLATFORMS } from '../constants/social-links.js';
import { bigintStringSchema, mediaUrlSchema, unixTimestampSchema } from './primitives.js';

/**
 * Core launch sale parameters shared by creation and on-chain validation.
 * Extracted so it can be reused in both the DTO layer and any SDK helpers.
 */
export const launchSaleParamsSchema = z.object({
  tokenPrice:          bigintStringSchema,
  saleTokenAllocation: bigintStringSchema,
  softCap:             bigintStringSchema,
  maxRaise:            bigintStringSchema,
  startTime:           unixTimestampSchema,
  endTime:             unixTimestampSchema,
}).superRefine((val, ctx) => {
  const now = Math.floor(Date.now() / 1000);

  if (val.startTime <= now) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['startTime'],
      message: 'startTime must be in the future',
    });
  }

  const duration = val.endTime - val.startTime;
  if (duration < LAUNCH_LIMITS.minSaleDurationSeconds) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['endTime'],
      message: `Sale duration must be at least ${LAUNCH_LIMITS.minSaleDurationSeconds / 3600} hours`,
    });
  }
  if (duration > LAUNCH_LIMITS.maxSaleDurationSeconds) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['endTime'],
      message: `Sale duration must not exceed ${LAUNCH_LIMITS.maxSaleDurationSeconds / 86400} days`,
    });
  }

  if (BigInt(val.maxRaise) < BigInt(val.softCap)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['maxRaise'],
      message: 'maxRaise must be greater than or equal to softCap',
    });
  }

  if (BigInt(val.tokenPrice) < BigInt(LAUNCH_LIMITS.minTokenPriceWad)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['tokenPrice'],
      message: `tokenPrice must be at least ${LAUNCH_LIMITS.minTokenPriceWad} wei`,
    });
  }
});

/**
 * Full launch metadata schema — used when creating or reviewing a launch draft.
 */
export const launchMetadataSchema = z.object({
  name: z
    .string()
    .min(3)
    .max(LAUNCH_LIMITS.maxNameLength)
    .trim(),

  tagline: z
    .string()
    .min(10)
    .max(LAUNCH_LIMITS.maxTaglineLength)
    .trim(),

  description: z
    .string()
    .min(50)
    .max(LAUNCH_LIMITS.maxDescriptionLength)
    .trim(),

  logoUrl:    mediaUrlSchema.nullable().optional(),
  bannerUrl:  mediaUrlSchema.nullable().optional(),
  websiteUrl: z.string().url().nullable().optional(),

  socialLinks: z
    .record(z.enum(SUPPORTED_SOCIAL_PLATFORMS), z.string().url())
    .optional(),
});

export type LaunchSaleParamsInput  = z.infer<typeof launchSaleParamsSchema>;
export type LaunchMetadataInput    = z.infer<typeof launchMetadataSchema>;
