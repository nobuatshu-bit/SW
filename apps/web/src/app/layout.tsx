import type { Metadata } from 'next';
import { Inter } from 'next/font/google';

import './globals.css';
import { Providers } from '@/components/providers';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
});

export const metadata: Metadata = {
  title: 'SHERWOOD — Fixed-price token launchpad on Base',
  description:
    'Launch and discover fixed-price token sales on Base. Transparent pricing, full refund protection, and non-custodial design. Built on Base Sepolia.',
  icons: {
    icon: '/assets/logo.png',
    shortcut: '/assets/logo.png',
    apple: '/assets/logo.png',
  },
  openGraph: {
    title: 'SHERWOOD — Fixed-price token launchpad on Base',
    description:
      'Launch and discover fixed-price token sales on Base. Transparent pricing, full refund protection, and non-custodial design.',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'SHERWOOD — Fixed-price token launchpad on Base',
    description:
      'Launch and discover fixed-price token sales on Base. Transparent pricing, full refund protection, and non-custodial design.',
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    // Force dark class — SHERWOOD is always dark-mode
    <html lang="en" className="dark" suppressHydrationWarning>
      <body className={inter.className}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
