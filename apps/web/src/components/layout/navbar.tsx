'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import { motion, useScroll, useTransform } from 'framer-motion';
import { useEffect, useState } from 'react';

import { cn } from '@/lib/utils';
import { NAV_LINKS } from '@/lib/constants';
import { SherwoodLogo } from '@/components/brand/sherwood-logo';
import Link from 'next/link';

export function Navbar() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const { scrollY } = useScroll();

  useEffect(() => {
    const unsubscribe = scrollY.on('change', (y) => {
      if (y > 60) setMobileOpen(false);
    });
    return unsubscribe;
  }, [scrollY]);

  const borderOpacity = useTransform(scrollY, [0, 80], [0, 1]);
  const bgOpacity = useTransform(scrollY, [0, 80], [0, 0.92]);

  return (
    <motion.header
      className="fixed inset-x-0 top-0 z-50"
      style={{ backdropFilter: 'blur(16px)', WebkitBackdropFilter: 'blur(16px)' }}
    >
      {/* Scrolled background */}
      <motion.div
        className="absolute inset-0 bg-[#050805]"
        style={{ opacity: bgOpacity }}
      />
      {/* Bottom border fades in on scroll */}
      <motion.div
        className="absolute inset-x-0 bottom-0 h-px bg-[rgba(167,230,53,0.18)]"
        style={{ opacity: borderOpacity }}
      />

      <nav className="relative mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
        {/* Logo: 36px mobile / 44px desktop — aspect ratio preserved, no crop */}
        <span className="md:hidden">
          <SherwoodLogo size={36} showWordmark />
        </span>
        <span className="hidden md:inline-flex">
          <SherwoodLogo size={44} showWordmark />
        </span>

        {/* Desktop links */}
        <ul className="hidden items-center gap-8 md:flex">
          {NAV_LINKS.map((link) => (
            <li key={link.href}>
              <Link
                href={link.href}
                className="text-sm font-medium text-[#7a9080] transition-colors duration-200 hover:text-[#A7E635]"
              >
                {link.label}
              </Link>
            </li>
          ))}
        </ul>

        {/* Right side */}
        <div className="flex items-center gap-3">
          <ConnectButton showBalance={false} chainStatus="none" accountStatus="avatar" />

          {/* Mobile toggle */}
          <button
            type="button"
            aria-label="Toggle menu"
            aria-expanded={mobileOpen}
            onClick={() => setMobileOpen((v) => !v)}
            className="flex h-9 w-9 flex-col items-center justify-center gap-1.5 rounded-md transition-colors hover:bg-[rgba(167,230,53,0.08)] md:hidden"
          >
            <span className={cn('block h-0.5 w-5 rounded-full bg-[#A7E635] transition-transform duration-200', mobileOpen && 'translate-y-2 rotate-45')} />
            <span className={cn('block h-0.5 w-5 rounded-full bg-[#A7E635] transition-opacity  duration-200', mobileOpen && 'opacity-0')} />
            <span className={cn('block h-0.5 w-5 rounded-full bg-[#A7E635] transition-transform duration-200', mobileOpen && '-translate-y-2 -rotate-45')} />
          </button>
        </div>
      </nav>

      {/* Mobile drawer */}
      <motion.div
        initial={false}
        animate={mobileOpen ? { height: 'auto', opacity: 1 } : { height: 0, opacity: 0 }}
        transition={{ duration: 0.22, ease: 'easeInOut' }}
        className="relative overflow-hidden border-b border-[rgba(167,230,53,0.12)] bg-[#050805]/95 md:hidden"
      >
        <ul className="flex flex-col gap-1 px-6 py-4">
          {NAV_LINKS.map((link) => (
            <li key={link.href}>
              <Link
                href={link.href}
                onClick={() => setMobileOpen(false)}
                className="block rounded-lg px-3 py-2.5 text-sm font-medium text-[#7a9080] transition-colors hover:bg-[rgba(167,230,53,0.07)] hover:text-[#A7E635]"
              >
                {link.label}
              </Link>
            </li>
          ))}
        </ul>
      </motion.div>
    </motion.header>
  );
}
