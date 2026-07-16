'use client';

import Image from 'next/image';
import { motion } from 'framer-motion';
import Link from 'next/link';

import { Button } from '@sherwood/ui';
import { cn } from '@/lib/utils';

const FADE_UP = {
  hidden: { opacity: 0, y: 28 },
  show:   { opacity: 1, y: 0 },
};

const STAGGER = {
  hidden: {},
  show: { transition: { staggerChildren: 0.13, delayChildren: 0.1 } },
};

interface PillProps {
  children: React.ReactNode;
  className?: string;
}

function Pill({ children, className }: PillProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full border border-[rgba(167,230,53,0.20)] bg-[rgba(167,230,53,0.06)] px-3 py-1 text-xs font-medium text-[#A7E635]/80',
        className,
      )}
    >
      {children}
    </span>
  );
}

export function Hero() {
  return (
    <section className="relative flex min-h-[calc(100svh-4rem)] flex-col items-center justify-center overflow-hidden px-6 pt-24 pb-16 text-center">

      {/* ── Forest depth gradient background ── */}
      <div
        className="pointer-events-none absolute inset-0 bg-forest"
        aria-hidden
      />

      {/* ── Treeline silhouette SVG overlay ── */}
      <svg
        className="pointer-events-none absolute bottom-0 left-0 right-0 w-full opacity-[0.07]"
        viewBox="0 0 1440 320"
        preserveAspectRatio="none"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden
      >
        <path
          d="M0,280 L60,240 L90,200 L120,240 L150,180 L180,220 L220,160 L260,210 L300,140 L340,190 L380,120 L420,170 L460,100 L500,155 L540,80 L580,140 L620,60 L660,130 L700,50 L740,120 L780,45 L820,115 L860,55 L900,125 L940,65 L980,135 L1020,75 L1060,145 L1100,85 L1140,155 L1180,95 L1220,165 L1260,105 L1300,180 L1340,130 L1380,200 L1420,155 L1440,220 L1440,320 L0,320 Z"
          fill="#A7E635"
        />
      </svg>

      {/* ── Decorative glow rings ── */}
      <div
        className="pointer-events-none absolute left-1/2 top-1/2 h-[500px] w-[500px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-[rgba(167,230,53,0.06)]"
        aria-hidden
      />
      <div
        className="pointer-events-none absolute left-1/2 top-1/2 h-[800px] w-[800px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-[rgba(167,230,53,0.03)]"
        aria-hidden
      />
      {/* Centre radial glow */}
      <div
        className="pointer-events-none absolute left-1/2 top-1/2 h-96 w-96 -translate-x-1/2 -translate-y-1/2 rounded-full bg-[rgba(167,230,53,0.05)] blur-3xl"
        aria-hidden
      />

      {/* ── Logo watermark ── */}
      <div
        className="pointer-events-none absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-[55%] opacity-[0.06] select-none"
        aria-hidden
      >
        <Image
          src="/assets/logo.png"
          alt=""
          width={600}
          height={600}
          style={{ width: 600, height: 600, objectFit: 'contain' }}
          priority
        />
      </div>

      {/* ── Content ── */}
      <motion.div
        variants={STAGGER}
        initial="hidden"
        animate="show"
        className="relative mx-auto flex max-w-4xl flex-col items-center gap-6"
      >
        {/* Eyebrow */}
        <motion.div variants={FADE_UP}>
          <Pill>
            <span className="h-1.5 w-1.5 rounded-full bg-[#A7E635] shadow-[0_0_6px_#A7E635]" />
            Now live on Base Sepolia
          </Pill>
        </motion.div>

        {/* Headline */}
        <motion.h1
          variants={FADE_UP}
          className="text-5xl font-black tracking-tight text-white sm:text-6xl lg:text-7xl"
        >
          Launch tokens.{' '}
          <span className="bg-gradient-to-r from-[#A7E635] to-[#6EEB3A] bg-clip-text text-transparent drop-shadow-[0_0_20px_rgba(167,230,53,0.4)]">
            Raise with confidence.
          </span>
        </motion.h1>

        {/* Sub-headline */}
        <motion.p
          variants={FADE_UP}
          className="max-w-xl text-lg text-[#7a9080] sm:text-xl"
        >
          SHERWOOD is a fixed-price token launchpad built on Base. Every buyer pays the same
          price. Funds are protected until graduation. No bonding curves. No surprises.
        </motion.p>

        {/* CTAs */}
        <motion.div
          variants={FADE_UP}
          className="flex flex-col items-center gap-3 sm:flex-row"
        >
          <Link href="#launches">
            <Button size="lg" className="min-w-44 rounded-full">
              Explore launches
            </Button>
          </Link>
          <Link href="#how-it-works">
            <Button size="lg" variant="outline" className="min-w-44 rounded-full">
              How it works
            </Button>
          </Link>
        </motion.div>

        {/* Trust pills */}
        <motion.div
          variants={FADE_UP}
          className="flex flex-wrap items-center justify-center gap-2.5 pt-2"
        >
          <Pill>⚡ Fixed price</Pill>
          <Pill>🔒 Non-custodial</Pill>
          <Pill>↩️ Mid-sale exit</Pill>
          <Pill>🛡️ Refund protected</Pill>
        </motion.div>
      </motion.div>

      {/* Scroll indicator */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.3, duration: 0.6 }}
        className="absolute bottom-8 left-1/2 -translate-x-1/2"
        aria-hidden
      >
        <motion.div
          animate={{ y: [0, 7, 0] }}
          transition={{ repeat: Infinity, duration: 2, ease: 'easeInOut' }}
          className="flex h-9 w-5 items-start justify-center rounded-full border-2 border-[rgba(167,230,53,0.25)] p-1"
        >
          <div className="h-1.5 w-1 rounded-full bg-[#A7E635]/60" />
        </motion.div>
      </motion.div>
    </section>
  );
}
