import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    // Allow Clerk-hosted avatars
    remotePatterns: [
      { protocol: "https", hostname: "img.clerk.com" },
      { protocol: "https", hostname: "images.clerk.dev" },
      { protocol: "https", hostname: "images.clerk.com" },
    ],
  },
};

export default nextConfig;
