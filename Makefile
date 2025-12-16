# OCPA-R3 & OCPA-R24: POSIX-compliant Makefile commands
# Required commands: dev, dev-[build,up,restart,down], prod, prod-[build,up,restart,down],
#                    helm-[deploy,uninstall], downa

.PHONY: dev dev-build dev-up dev-restart dev-down \
        build up restart down \
        prod prod-build prod-up prod-restart prod-down \
        test helm-deploy helm-uninstall downa

# Dev environment (default aliases)
dev: dev-up

dev-build:
	docker compose -f compose.dev.yml build

dev-up:
	docker compose -f compose.dev.yml up -d --build

dev-restart:
	docker compose -f compose.dev.yml restart

dev-down:
	docker compose -f compose.dev.yml down

# Aliases for dev commands (OCPA-R3)
build: dev-build
up: dev-up
restart: dev-restart
down: dev-down

# Prod environment
prod: prod-up

prod-build:
	docker compose -f compose.prod.yml build

prod-up:
	docker compose -f compose.prod.yml up -d --build

prod-restart:
	docker compose -f compose.prod.yml restart

prod-down:
	docker compose -f compose.prod.yml down

# Test environment
test:
	docker compose -f compose.test.yml up --build --abort-on-container-exit --exit-code-from test
	docker compose -f compose.test.yml down

# Helm commands
helm-deploy:
	./scripts/deploy-helm.sh deploy

helm-uninstall:
	./scripts/deploy-helm.sh uninstall

# Remove orphan containers without removing volumes (OCPA-R3)
downa:
	docker compose -f compose.dev.yml down --remove-orphans
	docker compose -f compose.prod.yml down --remove-orphans

# Utility commands
logs:
	docker compose -f compose.dev.yml logs -f

logs-prod:
	docker compose -f compose.prod.yml logs -f
