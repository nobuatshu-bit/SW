import { z } from 'zod';
import { mediaUrlSchema } from './primitives.js';

/**
 * Validates the user profile update payload — submitted by the frontend
 * when the user edits their display name or avatar.
 * All fields are optional; only provided fields are updated.
 */
export const updateUserProfileSchema = z.object({
  displayName: z
    .string()
    .min(2, 'Display name must be at least 2 characters')
    .max(50, 'Display name must be at most 50 characters')
    .trim()
    .optional(),

  avatarUrl: mediaUrlSchema.nullable().optional(),
});

export type UpdateUserProfileInput = z.infer<typeof updateUserProfileSchema>;
