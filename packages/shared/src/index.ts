import { z } from 'zod';

export const environmentSchema = z.enum(['development', 'test', 'production']);
export type Environment = z.infer<typeof environmentSchema>;

export const healthResponseSchema = z.object({
  status: z.literal('ok'),
  service: z.string(),
  timestamp: z.string().datetime(),
});
export type HealthResponse = z.infer<typeof healthResponseSchema>;

export function isDefined<T>(value: T | null | undefined): value is T {
  return value !== null && value !== undefined;
}
