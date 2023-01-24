# -------------------- Dependency Stage -------------------- #
FROM alpine as deps
WORKDIR /app
RUN apk add --update --no-cache nodejs yarn libc6-compat

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then yarn global add npm && npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# -------------------- Build Stage -------------------- #
FROM alpine as builder
WORKDIR /app
RUN apk add --update --no-cache nodejs yarn

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NODE_ENV=production \
  NEXT_TELEMETRY_DISABLED=1

# build the application and reinstall dependencies in "production mode"
RUN yarn build && \
  rm -r node_modules && \
  yarn install --frozen-lockfile

# -------------------- Copy Stage -------------------- #
FROM alpine as copy
WORKDIR /app

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY ./public ./public
COPY ./next.config.js ./

# -------------------- Deployment Stage -------------------- #
FROM alpine as deploy
WORKDIR /app
RUN apk add --update --no-cache nodejs && \
  addgroup --system --gid 1001 nodejs && \
  adduser --system --uid 1001 nextjs

COPY --from=copy --chown=nextjs:nodejs /app/. ./

USER nextjs

EXPOSE 3000
ENV NODE_ENV=production \
  NEXT_TELEMETRY_DISABLED=1 \
  PORT=3000

CMD ["node", "server.js"]