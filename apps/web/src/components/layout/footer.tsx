import Link from 'next/link';

import { Separator } from '@/components/ui/separator';
import { FOOTER_LINKS } from '@/lib/constants';
import { SherwoodLogo } from '@/components/brand/sherwood-logo';

export function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="border-t border-[rgba(167,230,53,0.10)] bg-[#08110A] px-6 py-12">
      <div className="mx-auto max-w-7xl">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
          {/* Brand column */}
          <div className="flex flex-col gap-4">
            <SherwoodLogo size={36} showWordmark />
            <p className="max-w-xs text-xs leading-relaxed text-[#7a9080]">
              A fixed-price token launchpad built on Base. Transparent pricing, full refund
              protection, and non-custodial design.
            </p>
            <p className="text-xs text-[#7a9080]/50">Built on Base Sepolia</p>
          </div>

          {/* Link columns */}
          {FOOTER_LINKS.map((col) => (
            <div key={col.heading} className="flex flex-col gap-3">
              <h4 className="text-xs font-bold uppercase tracking-widest text-[#A7E635]">
                {col.heading}
              </h4>
              <ul className="flex flex-col gap-2">
                {col.links.map((link) => (
                  <li key={link.label}>
                    <Link
                      href={link.href}
                      className="text-sm text-[#7a9080] transition-colors duration-200 hover:text-[#A7E635]"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <Separator className="my-8 bg-[rgba(167,230,53,0.08)]" />

        <div className="flex flex-col items-center justify-between gap-3 text-xs text-[#7a9080] sm:flex-row">
          <p>© {year} SHERWOOD. All rights reserved.</p>
          <p className="flex items-center gap-1.5">
            <span className="h-1.5 w-1.5 rounded-full bg-[#A7E635] shadow-[0_0_6px_#A7E635]" />
            All systems operational
          </p>
        </div>
      </div>
    </footer>
  );
}
