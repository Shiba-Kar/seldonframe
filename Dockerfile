# ---------- builder ----------
FROM node:22-bookworm-slim AS builder

ENV PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH \
    NEXT_TELEMETRY_DISABLED=1

RUN corepack enable

WORKDIR /app

# Copy workspace
COPY . .

# Normalize shell scripts in case repo was cloned on Windows
RUN find . -name '*.sh' -type f -exec sed -i 's/\r$//' {} +

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build-time placeholder environment variables
# These are NOT production secrets.
ENV DATABASE_URL=postgres://build:build@127.0.0.1:5432/build \
    AUTH_SECRET=build-only-not-a-real-secret \
    NEXTAUTH_SECRET=build-only-not-a-real-secret \
    ENCRYPTION_KEY=0000000000000000000000000000000000000000000000000000000000000000 \
    NEXT_PUBLIC_APP_URL=http://localhost:8080

RUN pnpm --filter @seldonframe/crm build


# ---------- runner ----------
FROM node:22-bookworm-slim AS runner

ENV NODE_ENV=production \
    PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=8080 \
    HOSTNAME=0.0.0.0

RUN corepack enable

WORKDIR /app

# curl   -> healthcheck
# tini   -> proper signal handling
# psql   -> migration script
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        tini \
        postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app ./

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["pnpm", "--filter", "@seldonframe/crm", "start"]