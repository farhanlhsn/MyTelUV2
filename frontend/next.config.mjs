// frontend/next.config.mjs
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactCompiler: true,
  // Jadikan folder "frontend" sebagai root Turbopack (hilangkan warning lockfile)
  turbopack: {
    root: __dirname,
  },
  // Proxy FE -> BE (BE kamu di 5050)
  async rewrites() {
    return [
      { source: '/api/:path*', destination: 'http://localhost:5050/:path*' },
    ];
  },
};

export default nextConfig;
