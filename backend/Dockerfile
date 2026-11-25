# Node.js Backend Dockerfile
# Multi-stage build for smaller image size

FROM node:22-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including devDependencies for Prisma)
RUN npm ci

# Copy prisma schema
COPY prisma ./prisma/

# Generate Prisma Client to ./generated/prisma
RUN npx prisma generate --schema prisma/schema.prisma

# Production stage
FROM node:22-alpine

# Business dates are Asia/Jakarta (WIB): tzdata makes TZ effective for the Node process
ENV TZ=Asia/Jakarta
RUN apk add --no-cache tzdata

WORKDIR /app
RUN chown node:node /app
USER node

# Production dependencies only. The `prisma` CLI is deliberately still present after
# --omit=dev (npm keeps it because @prisma/client lists it as an optional peer, lockfile flag
# "devOptional"): the deploy runs `npx prisma migrate deploy` inside this image before `up -d`.
# The check fails the build instead of the deploy if a future npm drops it.
COPY --chown=node:node package*.json ./
RUN npm ci --omit=dev \
    && npm cache clean --force \
    && test -x node_modules/.bin/prisma

# Copy generated Prisma client (output is at ./generated/prisma)
COPY --from=builder --chown=node:node /app/generated ./generated

# Copy application files
COPY --chown=node:node prisma ./prisma/
COPY --chown=node:node server.js ./
COPY --chown=node:node config ./config/
COPY --chown=node:node controllers ./controllers/
COPY --chown=node:node middlewares ./middlewares/
COPY --chown=node:node routes ./routes/
COPY --chown=node:node utils ./utils/
# Static assets (PDF report logo: assets/telyu.png)
COPY --chown=node:node assets ./assets/

# Writable directories: uploads (bind mount) and logs (named volume; the volume takes the
# ownership of this directory the first time it is mounted)
RUN mkdir -p uploads logs

# Expose port
EXPOSE 5050

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:5050/health || exit 1

# Start the application
CMD ["node", "server.js"]
