'use client';

import { motion } from 'framer-motion';

import { Badge } from '@/components/ui/badge';
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { TRENDING_LAUNCHES, type LaunchStatus } from '@/lib/constants';
import { cn } from '@/lib/utils';

// ─── Animated progress bar ───────────────────────────────────────────────────

function ProgressBar({ pct }: { pct: number }) {
  return (
    <div className="h-1.5 w-full overflow-hidden rounded-full bg-[rgba(167,230,53,0.10)]">
      <motion.div
        className="h-full rounded-full bg-gradient-to-r from-[#A7E635] to-[#6EEB3A]"
        style={{ boxShadow: '0 0 8px rgba(167,230,53,0.50)' }}
        initial={{ width: 0 }}
        whileInView={{ width: `${pct}%` }}
        viewport={{ once: true }}
        transition={{ duration: 0.85, ease: 'easeOut', delay: 0.2 }}
      />
    </div>
  );
}

// ─── Status badge ─────────────────────────────────────────────────────────────

const STATUS_MAP: Record<LaunchStatus, { label: string; variant: 'success' | 'warning' | 'secondary' }> = {
  live:      { label: 'Live',      variant: 'success'   },
  upcoming:  { label: 'Upcoming',  variant: 'warning'   },
  graduated: { label: 'Graduated', variant: 'secondary' },
};

// ─── Avatar ───────────────────────────────────────────────────────────────────

function Avatar({ label }: { label: string }) {
  return (
    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-[rgba(167,230,53,0.20)] bg-[rgba(167,230,53,0.08)] text-xs font-bold text-[#A7E635]">
      {label}
    </div>
  );
}

// ─── Launch card ─────────────────────────────────────────────────────────────

function LaunchCard({ launch }: { launch: (typeof TRENDING_LAUNCHES)[number] }) {
  const { label, variant } = STATUS_MAP[launch.status];

  return (
    <Card className="group flex flex-col rounded-2xl border-[rgba(167,230,53,0.10)] bg-[#111814] transition-all duration-300 hover:border-[rgba(167,230,53,0.35)] hover:shadow-[0_0_24px_rgba(167,230,53,0.08)]">
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-center gap-3">
            <Avatar label={launch.avatarLabel} />
            <div>
              <CardTitle className="text-base text-white">{launch.name}</CardTitle>
              <span className="font-mono text-xs text-[#7a9080]">{launch.symbol}</span>
            </div>
          </div>
          <Badge variant={variant}>{label}</Badge>
        </div>
        <CardDescription className="mt-2 line-clamp-2 text-xs leading-relaxed text-[#7a9080]">
          {launch.description}
        </CardDescription>
      </CardHeader>

      <CardContent className="flex-1 space-y-3 pb-3">
        <ProgressBar pct={launch.progressPct} />
        <div className="flex items-center justify-between text-xs text-[#7a9080]">
          <span>
            <span className="font-semibold text-white">{launch.raised}</span> raised
          </span>
          <span>Target: {launch.target}</span>
        </div>
      </CardContent>

      <CardFooter className="border-t border-[rgba(167,230,53,0.08)] pt-3 text-xs text-[#7a9080]">
        <div className="flex w-full items-center justify-between">
          <span>
            {launch.participants > 0
              ? `${launch.participants.toLocaleString()} participants`
              : 'No participants yet'}
          </span>
          <span
            className={cn(
              'font-medium',
              launch.status === 'live' && 'text-[#A7E635]',
            )}
          >
            {launch.endsIn}
          </span>
        </div>
      </CardFooter>
    </Card>
  );
}

// ─── Section ─────────────────────────────────────────────────────────────────

const STAGGER = {
  hidden: {},
  show: { transition: { staggerChildren: 0.08 } },
};

const FADE_UP = {
  hidden: { opacity: 0, y: 20 },
  show:   { opacity: 1, y: 0, transition: { duration: 0.45, ease: 'easeOut' } },
};

export function TrendingLaunches() {
  return (
    <section id="launches" className="bg-[#050805] py-20 px-6">
      <div className="mx-auto max-w-7xl">
        {/* Section header */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-60px' }}
          transition={{ duration: 0.5 }}
          className="mb-10 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between"
        >
          <div>
            <p className="mb-1 text-xs font-bold uppercase tracking-widest text-[#A7E635]">
              Trending now
            </p>
            <h2 className="text-3xl font-black tracking-tight text-white sm:text-4xl">
              Active launches
            </h2>
          </div>
          <p className="text-sm text-[#7a9080] sm:text-right">
            Fixed-price sales on Base Sepolia.
            <br className="hidden sm:block" /> All funds refundable until graduation.
          </p>
        </motion.div>

        {/* Grid */}
        <motion.div
          variants={STAGGER}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: '-40px' }}
          className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3"
        >
          {TRENDING_LAUNCHES.map((launch) => (
            <motion.div key={launch.id} variants={FADE_UP}>
              <LaunchCard launch={launch} />
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
