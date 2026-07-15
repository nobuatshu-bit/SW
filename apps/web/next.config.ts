import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  transpilePackages: ['@sherwood/sdk', '@sherwood/shared', '@sherwood/ui'],
};

export default nextConfig;
