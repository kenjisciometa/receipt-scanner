import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Empty turbopack config to silence webpack warning
  turbopack: {},
  webpack: (config: any) => {
    // Force webpack mode by ensuring config exists
    return config;
  },
};

export default nextConfig;
