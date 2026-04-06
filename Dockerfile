# ===========================================================================
# SecureFin App — Multi-stage Dockerfile
# ===========================================================================
# WHY multi-stage:
#   Stage 1 (builder) — installs npm dependencies. Build-time tools
#   (npm, gcc, python) exist only here and are discarded.
#
#   Stage 2 (runtime) — copies ONLY production deps + source into a
#   distroless base. Final image has no shell, no package manager,
#   no OS utilities — smallest possible attack surface.
#
# WHY node:18-alpine (builder):
#   Alpine is ~50 MB vs ~350 MB for Debian-based. We only need npm
#   to install deps; the builder is thrown away after.
#
# WHY distroless (runtime):
#   - No shell → cannot exec into the container (blocks RCE exploits)
#   - No package manager → cannot install malware at runtime
#   - No OS utils → eliminates tools attackers rely on (curl, wget, nc)
#   - ~30 MB base vs ~120 MB for alpine
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
# Stage 2: Runtime — minimal distroless image
# ---------------------------------------------------------------------------
FROM gcr.io/distroless/nodejs18-debian12:nonroot

WORKDIR /app

# Copy only what the app needs — no build tools, no npm cache
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./

# Distroless 'nonroot' tag sets UID 65534 by default.
# We match the K8s securityContext (runAsUser: 1000) for consistency.
USER 1000

ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080

# Distroless nodejs images use the Node.js binary as entrypoint.
# We only need to specify the script path.
CMD ["src/index.js"]
