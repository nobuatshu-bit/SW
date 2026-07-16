import { z } from 'zod';
import { createLaunchRequestSchema } from './create-launch.request.js';

/**
 * Request body for PATCH /launches/:id.
 * All fields are optional — only provided fields are updated.
 * On-chain parameters (tokenPrice, softCap, etc.) cannot be changed once the
 * contract is deployed; the backend enforces this constraint.
 */
export const updateLaunchRequestSchema = createLaunchRequestSchema
  .pick({
    // Off-chain-only fields that can be updated at any stage
    name: true,
    tagline: true,
    description: true,
    logoUrl: true,
    bannerUrl: true,
    websiteUrl: true,
    socialLinks: true,
  })
  .partial();

export type UpdateLaunchRequest = z.infer<typeof updateLaunchRequestSchema>;
