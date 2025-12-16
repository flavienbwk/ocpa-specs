# OCPA-R1: Fixed versions for base image and packages
FROM node:20.18.1-alpine3.20 AS base

WORKDIR /app

# Install markserv with fixed version
# OCPA-R1: Fixed version for markserv
RUN npm install -g markserv@1.19.0

# Install wget for healthcheck
RUN apk add --no-cache wget

EXPOSE 8642

# Development target - uses volume mounts for hot-reload
FROM base AS dev
CMD ["markserv", "-p", "8642", "-a", "0.0.0.0", "/app"]

# Production target - static files baked into image
FROM base AS prod
# Copy documentation files (from root context)
COPY README.md ./README.md
COPY docs ./docs
CMD ["markserv", "-p", "8642", "-a", "0.0.0.0", "/app"]
