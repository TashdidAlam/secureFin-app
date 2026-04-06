# ===========================================================================
# SecureFin App — Multi-stage Dockerfile
# ===========================================================================
# WHY multi-stage:
#   Stage 1 (builder) — installs npm dependencies. Build-time tools
#   (npm, gcc, python) exist only here and are discarded.
#
#   Stage 2 (runtime) — copies ONLY production deps + source into a
#   minimal Alpine base. Final image has no dev tools, no npm cache.
#
# WHY node:18-alpine (builder + runtime):
#   Alpine is ~50 MB vs ~350 MB for Debian-based. Uses musl/LibreSSL
#   instead of OpenSSL — not affected by Debian OpenSSL CVEs.
#   The runtime stage strips the image down to only app files.
#
# WHY non-root:
#   Even if an attacker escapes the app process, they land as UID 1000
#   with no write access to system paths. Combined with
#   readOnlyRootFilesystem in the K8s securityContext, the container
#   is effectively immutable at runtime.
#
# FINAL IMAGE SIZE: ~60 MB
# ===========================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build — install production dependencies
# ---------------------------------------------------------------------------
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package manifests first for Docker layer caching.
# If only source code changes, npm ci is skipped (cached layer).
COPY backend/package.json backend/package-lock.json* ./

# --omit=dev excludes devDependencies (test frameworks, linters).
RUN npm ci --omit=dev

# Copy backend source
COPY backend/src/ ./src/

# Copy frontend static files into public/ (served by Express)
COPY frontend/ ./public/

# ---------------------------------------------------------------------------
# Stage 2: Runtime — minimal Alpine image (no dev tools, no npm)
# ---------------------------------------------------------------------------
FROM node:18-alpine

# Patch OS-level CVEs (e.g. CVE-2025-15467 in libcrypto3/libssl3), then
# remove npm/yarn/corepack (not needed at runtime — reduces attack surface)
RUN apk update && apk upgrade --no-cache \
    && npm cache clean --force \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx \
              /opt/yarn-* /usr/local/bin/yarn /usr/local/bin/yarnpkg \
              /usr/local/lib/node_modules/corepack /usr/local/bin/corepack \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Copy only what the app needs — no build tools, no npm cache
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./

# Run as non-root UID 1000 — matches K8s securityContext (runAsUser: 1000)
USER 1000

ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080

CMD ["node", "src/index.js"]
