.PHONY: help build up down restart logs ps test clean

# Variables
COMPOSE = docker-compose
COMPOSE_DEV = docker-compose -f docker-compose.yml -f docker-compose.dev.yml
COMPOSE_PROD = docker-compose -f docker-compose.yml -f docker-compose.prod.yml

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# Development commands
build: ## Build Docker images
	$(COMPOSE) build

up: ## Start all services (production mode - data persists)
	$(COMPOSE) up -d
	@echo "Services started in PRODUCTION mode!"
	@echo "API: http://localhost:8000"
	@echo "API Docs: http://localhost:8000/docs"
	@echo "Flower: http://localhost:5555"
	@echo ""
	@echo "Note: Data is persistent and will survive restarts."

dev: ## Start services in development mode with hot-reload
	$(COMPOSE_DEV) up -d
	@echo "Services started in DEVELOPMENT mode!"
	@echo "API: http://localhost:8000 (with hot-reload)"
	@echo "API Docs: http://localhost:8000/docs"
	@echo "Flower: http://localhost:5555"
	@echo ""
	@echo "Note: Source code is mounted for hot-reload, but data is still persistent."

down: ## Stop all services
	$(COMPOSE) down

restart: ## Restart all services
	$(COMPOSE) restart

logs: ## Show logs for all services
	$(COMPOSE) logs -f

logs-api: ## Show API logs
	$(COMPOSE) logs -f api

logs-worker: ## Show worker logs
	$(COMPOSE) logs -f worker

ps: ## Show running containers
	$(COMPOSE) ps

shell-api: ## Open shell in API container
	$(COMPOSE) exec api /bin/bash

shell-worker: ## Open shell in worker container
	$(COMPOSE) exec worker /bin/bash

# Production commands
prod-build: ## Build production images
	$(COMPOSE_PROD) build

prod-up: ## Start production services
	$(COMPOSE_PROD) up -d

prod-down: ## Stop production services
	$(COMPOSE_PROD) down

prod-logs: ## Show production logs
	$(COMPOSE_PROD) logs -f

# Testing
test: ## Run tests in Docker
	$(COMPOSE) exec api pytest tests/ -v

test-cov: ## Run tests with coverage
	$(COMPOSE) exec api pytest tests/ --cov=. --cov-report=html

# Database
db-shell: ## Open database shell
	$(COMPOSE) exec api sqlite3 /app/data/orbi.db

db-backup: ## Backup database
	$(COMPOSE) exec api cp /app/data/orbi.db /app/data/orbi_backup_$(shell date +%Y%m%d_%H%M%S).db

# Maintenance
clean: ## Remove all containers, volumes, and images
	$(COMPOSE) down -v
	docker system prune -f

clean-models: ## Remove downloaded ML models
	docker volume rm orbi_orbi-models || true

rebuild: clean build up ## Clean rebuild everything

# Monitoring
stats: ## Show container stats
	docker stats orbi-api orbi-worker orbi-redis

# Installation
install: ## Create .env file from example
	@if [ ! -f be/.env ]; then \
		cp be/.env.example be/.env; \
		echo "Created be/.env file. Please edit it with your API keys."; \
	else \
		echo "be/.env already exists."; \
	fi

setup: install build ## Initial setup (create .env and build)
	@echo "Setup complete! Run 'make up' to start services."

# Quick start
start: up ## Alias for 'up'

stop: down ## Alias for 'down'

# Health check
health: ## Check health of all services
	@echo "Checking Redis..."
	@$(COMPOSE) exec redis redis-cli ping || echo "Redis not healthy"
	@echo "Checking API..."
	@curl -f http://localhost:8000/health || echo "API not healthy"

# Default target
.DEFAULT_GOAL := help
