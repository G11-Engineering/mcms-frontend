# syntax=docker.io/docker/dockerfile:1
FROM node:24-alpine AS base

# Install dependencies only when needed
FROM base AS deps

RUN corepack enable
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn/releases ./.yarn/releases
RUN yarn --frozen-lockfile

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules

COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn/releases ./.yarn/releases

COPY next.config.mjs tsconfig.json postcss.config.cjs theme.ts ./
COPY app ./app
COPY components ./components
COPY public ./public

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
# ENV NEXT_TELEMETRY_DISABLED=1

RUN yarn run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
# Uncomment the following line in case you want to disable telemetry during runtime.
# ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs \
&& adduser --system --uid 1001 nextjs

WORKDIR /app

# Copy Yarn binary + config
COPY .yarn/releases ./.yarn/releases
COPY .yarnrc.yml ./

# Copy only needed files
COPY package.json yarn.lock ./

# Install only production dependencies
RUN yarn workspaces focus --production

# Copy build artifacts and public folder (non-standalone)
COPY --from=builder --chown=root:root --chmod=755 /app/.next ./.next
COPY --from=builder --chown=root:root --chmod=755 /app/public ./public

USER nextjs

# Expose port
EXPOSE 3000

# Start Next.js in production mode
CMD ["yarn", "start"]
