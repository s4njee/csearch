# CSearch developer entry points. See DEV_SETUP.md for the full guide.
.DEFAULT_GOAL := help

POSTGRES_PASSWORD ?= change-me-local-postgres
LOCAL_DSN ?= postgresql://postgres:$(POSTGRES_PASSWORD)@localhost:5433/csearch

.PHONY: help dev down logs migrate seed test api-test rust-test frontend-build \
        db-smoke eval hygiene schema-drift

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

dev: ## Start Postgres (migrated+seeded), Redis, and the API locally
	docker compose up --build postgres redis api

down: ## Stop and remove the local stack
	docker compose down

logs: ## Tail the local stack logs
	docker compose logs -f

migrate: ## Apply DB migrations to the local Postgres (port 5433)
	python3 db/migrate.py --dsn "$(LOCAL_DSN)"

seed: ## Load fixture corpus into the local Postgres
	psql "$(LOCAL_DSN)" -v ON_ERROR_STOP=1 -f db/seed/fixtures.sql

test: api-test rust-test ## Run API + scraper test suites

api-test: ## Run the FastAPI test suite
	cd backend/api && python -m pytest -q

rust-test: ## Run the Rust scraper test suite
	cd backend/scraper && cargo test --quiet

frontend-build: ## Type-generate and build the frontend
	cd frontend && npm ci && npm run generate

db-smoke: ## Ephemeral Postgres: migrate + seed + pgvector smoke assertions
	bash scripts/db-smoke.sh

eval: ## Run the retrieval eval against fixtures (no OpenAI key needed)
	uv run backend/nlp/eval/run_eval.py --provider fake --only-fixtures --mode vector --dsn "$(LOCAL_DSN)"

hygiene: ## Run repo hygiene + schema drift checks
	bash scripts/check-repo-hygiene.sh
	bash scripts/check-schema-drift.sh

schema-drift: ## Check schema bootstrap copies have not drifted
	bash scripts/check-schema-drift.sh
