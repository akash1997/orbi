# Docker Deployment Guide

Complete guide for running Orbi Speaker Intelligence API with Docker.

## Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- 4GB+ RAM
- 10GB+ disk space

### 1. Setup Environment

```bash
# Clone repository (if not already done)
cd orbi

# Create .env file
make install
# OR manually:
cp be/.env.example be/.env
```

Edit `be/.env` and add your API keys:
```env
HF_TOKEN=your_huggingface_token
OPENAI_API_KEY=your_openai_key
# OR
ANTHROPIC_API_KEY=your_anthropic_key
```

### 2. Start Services

```bash
# Build and start all services
make up

# OR use docker-compose directly
docker-compose up -d
```

### 3. Access Services

- **API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **Flower (Celery Monitor)**: http://localhost:5555
- **Health Check**: http://localhost:8000/health

## Architecture

```
┌──────────────┐
│   Client     │
└──────┬───────┘
       │
┌──────▼────────┐
│  nginx:80     │ (optional, production)
└──────┬────────┘
       │
┌──────▼────────┐
│   api:8000    │ FastAPI Application
└───────────────┘
       │
       ├─────┐
       │     │
┌──────▼─────▼────┐
│   redis:6379    │ Message Broker
└───────┬─────────┘
        │
┌───────▼─────────┐
│  worker (×N)    │ Celery Workers
└─────────────────┘
        │
┌───────▼─────────┐
│  flower:5555    │ Monitoring
└─────────────────┘
```

## Services

### API Service
- **Container**: `orbi-api`
- **Port**: 8000
- **Purpose**: FastAPI web application
- **Replicas**: 1 (dev), 2+ (prod)

### Worker Service
- **Container**: `orbi-worker`
- **Purpose**: Celery worker for async processing
- **Replicas**: 1 (dev), 2+ (prod)
- **Concurrency**: 2 (dev), 4+ (prod)

### Redis Service
- **Container**: `orbi-redis`
- **Port**: 6379
- **Purpose**: Message broker and result backend
- **Persistence**: Yes (AOF)

### Flower Service
- **Container**: `orbi-flower`
- **Port**: 5555
- **Purpose**: Celery monitoring dashboard

## Makefile Commands

```bash
# Development
make help          # Show all commands
make setup         # Initial setup
make up            # Start services
make down          # Stop services
make restart       # Restart services
make logs          # Show all logs
make logs-api      # Show API logs
make logs-worker   # Show worker logs
make ps            # Show container status

# Testing
make test          # Run tests
make test-cov      # Run tests with coverage

# Maintenance
make clean         # Remove containers and volumes
make rebuild       # Clean rebuild
make health        # Check service health
make stats         # Show resource usage

# Production
make prod-up       # Start in production mode
make prod-down     # Stop production
make prod-logs     # Production logs

# Database
make db-shell      # Open database shell
make db-backup     # Backup database

# Development
make shell-api     # Shell in API container
make shell-worker  # Shell in worker container
```

## Development Workflow

### Starting Development

```bash
# 1. Setup (first time only)
make setup

# 2. Edit .env file with API keys
nano be/.env

# 3. Start services
make up

# 4. Check logs
make logs

# 5. Test API
curl http://localhost:8000/health
```

### Making Changes

The development setup uses volume mounts, so code changes are reflected immediately:

```bash
# API changes trigger auto-reload (uvicorn --reload)
# Edit files in be/ directory

# Restart worker after changes
docker-compose restart worker

# View logs
make logs-api
make logs-worker
```

### Running Tests

```bash
# Run tests in container
make test

# With coverage
make test-cov

# Specific test file
docker-compose exec api pytest tests/test_api.py -v
```

### Debugging

```bash
# Open shell in API container
make shell-api

# Check Python packages
docker-compose exec api pip list

# Check environment variables
docker-compose exec api env

# View real-time logs
make logs

# Check container resources
make stats
```

## Production Deployment

### Using Production Compose

```bash
# Build production images
make prod-build

# Start production services
make prod-up

# Check status
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps

# View logs
make prod-logs
```

### Production Configuration

Production setup includes:
- **No --reload**: Stable uvicorn without auto-reload
- **Multiple workers**: 4 uvicorn workers
- **Worker scaling**: 2+ Celery workers
- **Resource limits**: CPU and memory limits
- **Restart policy**: Always restart on failure
- **Health checks**: Automatic health monitoring

### Environment Variables for Production

```env
# Production settings
DEBUG=False
MAX_AUDIO_DURATION=600

# Use smaller models for faster processing
WHISPER_MODEL=base

# Resource limits
CELERY_MAX_TASKS_PER_CHILD=100

# Security
FLOWER_BASIC_AUTH=admin:secure_password_here
```

## Volume Management

### Persistent Data

```yaml
volumes:
  redis-data:      # Redis persistence
  orbi-data:       # Database, recordings, embeddings
  orbi-models:     # Downloaded ML models (cached)
```

### Backup Data

```bash
# Backup database
make db-backup

# Backup entire data volume
docker run --rm -v orbi_orbi-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/orbi-data-backup.tar.gz -C /data .

# Restore data
docker run --rm -v orbi_orbi-data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/orbi-data-backup.tar.gz -C /data
```

### Clean Up

```bash
# Remove all containers and volumes
make clean

# Remove just models (force re-download)
make clean-models

# Remove specific volume
docker volume rm orbi_orbi-data
```

## Troubleshooting

### Services Won't Start

```bash
# Check logs
make logs

# Check if ports are in use
lsof -i :8000
lsof -i :6379

# Rebuild from scratch
make rebuild
```

### API is Slow

```bash
# Check resource usage
make stats

# Increase worker concurrency
# Edit docker-compose.yml:
#   worker:
#     command: celery ... --concurrency=4
```

### Models Not Loading

```bash
# Check HF_TOKEN is set
docker-compose exec api env | grep HF_TOKEN

# Download models manually
docker-compose exec api python -c "
from pyannote.audio import Pipeline
pipeline = Pipeline.from_pretrained('pyannote/speaker-diarization-3.1')
"
```

### Out of Memory

```bash
# Reduce model size
# Edit .env:
WHISPER_MODEL=tiny  # or base instead of medium/large

# Increase Docker memory limit
# Docker Desktop > Settings > Resources > Memory: 8GB+
```

### Worker Crashes

```bash
# Check worker logs
make logs-worker

# Restart worker
docker-compose restart worker

# Reduce concurrency
# Edit docker-compose.yml:
#   worker:
#     command: celery ... --concurrency=1
```

## Monitoring

### Flower Dashboard

Access at http://localhost:5555

- View active tasks
- Monitor worker status
- See task history
- Check task success/failure rates

### Logs

```bash
# All services
make logs

# Specific service
docker-compose logs -f api
docker-compose logs -f worker
docker-compose logs -f redis

# Last 100 lines
docker-compose logs --tail=100 api
```

### Health Checks

```bash
# Automated health check
make health

# Manual checks
curl http://localhost:8000/health
docker-compose ps
```

### Resource Usage

```bash
# Real-time stats
make stats

# Docker system info
docker system df
docker system info
```

## Scaling

### Horizontal Scaling

```bash
# Scale workers
docker-compose up -d --scale worker=4

# Scale API (with load balancer)
docker-compose up -d --scale api=2
```

### Vertical Scaling

Edit `docker-compose.prod.yml`:

```yaml
services:
  worker:
    deploy:
      resources:
        limits:
          cpus: '8'
          memory: 8G
```

## Security

### API Keys

Never commit .env files:
```bash
# .env is in .gitignore
# Use secrets management in production
```

### Network

```bash
# Isolate services
# Only expose necessary ports
# Use internal network for inter-service communication
```

### Updates

```bash
# Update base images
docker-compose pull
docker-compose up -d

# Update Python dependencies
docker-compose build --no-cache
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Docker Build

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: docker-compose build
      - name: Test
        run: docker-compose run api pytest
```

## Performance Tips

1. **Use smaller models** for dev: `WHISPER_MODEL=tiny`
2. **Cache models**: Models persist in `orbi-models` volume
3. **Increase workers**: Scale based on CPU cores
4. **Use SSD**: For better I/O performance
5. **GPU support**: Use nvidia-docker for GPU acceleration

## Maintenance

### Regular Tasks

```bash
# Weekly: Check logs for errors
make logs | grep ERROR

# Monthly: Backup database
make db-backup

# As needed: Clean up old containers
docker system prune -a

# As needed: Update dependencies
docker-compose build --no-cache
```

### Monitoring Checklist

- [ ] API response time < 200ms
- [ ] Worker processing time reasonable
- [ ] Disk space > 20% free
- [ ] Memory usage < 80%
- [ ] No errors in logs
- [ ] All health checks passing

## Support

For issues:
1. Check logs: `make logs`
2. Check health: `make health`
3. Check resources: `make stats`
4. Review this guide
5. Open GitHub issue with logs

## Quick Reference

```bash
# Start
make up

# Stop
make down

# Logs
make logs

# Test
make test

# Clean
make clean

# Rebuild
make rebuild
```

That's it! You should now have Orbi running in Docker. 🚀
