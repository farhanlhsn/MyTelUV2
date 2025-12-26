# Node.js Backend Dockerfile
# Multi-stage build for smaller image size

FROM node:20-alpine AS builder

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
FROM node:20-alpine

WORKDIR /app

# Copy node_modules
COPY --from=builder /app/node_modules ./node_modules

# Copy generated Prisma client (output is at ./generated/prisma)
COPY --from=builder /app/generated ./generated

# Copy application files
COPY package*.json ./
COPY prisma ./prisma/
COPY server.js ./
COPY config ./config/
COPY controllers ./controllers/
COPY middlewares ./middlewares/
COPY routes ./routes/
COPY utils ./utils/

# Create uploads directory
RUN mkdir -p uploads

# Expose port
EXPOSE 5050

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5050/ || exit 1

# Start the application
CMD ["node", "server.js"]
