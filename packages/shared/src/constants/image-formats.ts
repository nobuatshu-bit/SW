/**
 * Permitted image MIME types and file extensions for logo and banner uploads.
 */
export const SUPPORTED_IMAGE_MIME_TYPES = [
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/webp',
  'image/gif',
  'image/svg+xml',
] as const;

export type SupportedImageMimeType = (typeof SUPPORTED_IMAGE_MIME_TYPES)[number];

export const SUPPORTED_IMAGE_EXTENSIONS = [
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.gif',
  '.svg',
] as const;

export const IMAGE_SIZE_LIMITS = {
  /** Maximum logo file size: 2 MB. */
  logoMaxBytes: 2 * 1024 * 1024,

  /** Maximum banner file size: 5 MB. */
  bannerMaxBytes: 5 * 1024 * 1024,

  /** Recommended logo dimensions in pixels. */
  logoRecommendedSize: { width: 400, height: 400 },

  /** Recommended banner dimensions in pixels. */
  bannerRecommendedSize: { width: 1200, height: 400 },
} as const;
