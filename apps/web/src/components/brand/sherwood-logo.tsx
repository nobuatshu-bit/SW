import Image from 'next/image';
import Link from 'next/link';

import { cn } from '@/lib/utils';

interface SherwoodLogoProps {
  /** px height of the logo image. Width auto-scales via aspect ratio. */
  size?: number;
  /** Show the SHERWOOD wordmark beside the logo. */
  showWordmark?: boolean;
  /** Additional classes on the root <Link>. */
  className?: string;
  /** Render as a plain <div> instead of a <Link>. Useful for hero watermark. */
  asDiv?: boolean;
}

/**
 * Primary SHERWOOD brand logo.
 * Uses the Robin Hood asset at /public/assets/logo.png.
 * All logo placements across the app import from this single component.
 *
 * Default sizes follow brand rules:
 *   Desktop navbar  → size={44}
 *   Mobile navbar   → size={36}
 *   Footer          → size={36}
 */
export function SherwoodLogo({
  size = 44,
  showWordmark = true,
  className,
  asDiv = false,
}: SherwoodLogoProps) {
  const logo = (
    <Image
      src="/assets/logo.png"
      alt="SHERWOOD logo"
      width={size}
      height={size}
      // Source image is square — maintain aspect ratio, never crop
      style={{ width: size, height: size, objectFit: 'contain' }}
      priority
    />
  );

  const wordmark = showWordmark ? (
    <span className="font-black tracking-[0.12em] text-white" style={{ fontSize: size * 0.38 }}>
      SHERWOOD
    </span>
  ) : null;

  const inner = (
    <span className="relative flex items-center gap-2.5">
      {/* Subtle glow halo behind logo */}
      <span
        className="pointer-events-none absolute rounded-full bg-[rgba(167,230,53,0.12)] blur-lg"
        style={{ width: size, height: size }}
        aria-hidden
      />
      {logo}
      {wordmark}
    </span>
  );

  if (asDiv) {
    return <div className={cn('inline-flex', className)}>{inner}</div>;
  }

  return (
    <Link
      href="/"
      className={cn(
        'inline-flex items-center transition-opacity duration-200 hover:opacity-80',
        className,
      )}
      aria-label="SHERWOOD — go to homepage"
    >
      {inner}
    </Link>
  );
}
