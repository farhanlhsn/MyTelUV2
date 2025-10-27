// backend/prisma.config.ts
import { defineConfig, env } from "prisma/config";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// path ke .env di ROOT project
const ROOT_ENV = path.resolve(__dirname, "../.env");

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: { path: "prisma/migrations" },
  engine: "classic",
  datasource: {
    // baca DATABASE_URL dari .env root
    url: env("DATABASE_URL"),
  },
});
