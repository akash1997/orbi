# Complete Setup Guide

This guide covers everything you need to get Orbi running, from zero to production.

## Table of Contents

- [Docker Setup (Recommended)](#docker-setup-recommended)
- [Manual Setup](#manual-setup)
- [Configuration](#configuration)
- [Testing](#testing)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)

## Docker Setup (Recommended)

### System Requirements

- **OS**: Linux, macOS, or Windows with WSL2
- **Docker**: 20.10+ with Docker Compose 2.0+
- **RAM**: 4GB minimum, 8GB+ recommended
- **Disk**: 10GB+ free space
- **CPU**: 2+ cores recommended

### Installation Steps

#### 1. Install Docker

**macOS**:
```bash
# Install Docker Desktop
brew install --cask docker
```

**Linux**:
```bash
# Install Docker Engine
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

**Windows**:
- Install Docker Desktop from https://www.docker.com/products/docker-desktop
- Enable WSL2

#### 2. Clone Repository

```bash
git clone <your-repo-url>
cd orbi
```

#### 3. Setup Environment

```bash
# Create .env file
make install

# Edit .env file
nano be/.env
```

Add your API keys to `be/.env`:
```env
# Required: HuggingFace token for pyannote models
HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxx

# Required: LLM provider
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxx
# OR
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxxx

# Optional: Adjust settings
WHISPER_MODEL=base  # tiny/base/small/medium/large
LLM_MODEL=gpt-4o-mini
```

#### 4. Start Services

```bash
# Build and start all services
make up

# Wait for services to be healthy (~30-60 seconds)
make health

# Check logs
make logs
```

#### 5. Verify Installation

```bash
# Check API health
curl http://localhost:8000/health

# Open API docs in browser
open http://localhost:8000/docs

# Check Flower (Celery monitor)
open http://localhost:5555
```

#### 6. Test Upload

```bash
# Upload a test audio file
curl -X POST "http://localhost:8000/upload" \
  -F "file=@/path/to/your/audio.mp3"

# You'll get back a job_id
# Check job status
curl "http://localhost:8000/jobs/{job_id}"
```

### Quick Commands

```bash
make up           # Start services
make down         # Stop services
make logs         # View logs
make restart      # Restart services
make test         # Run tests
make clean        # Clean everything
make help         # Show all commands
```

---

## Manual Setup

For development without Docker.

### Prerequisites

#### 1. Python 3.10+

```bash
# Check version
python3 --version

# Install if needed
# macOS
brew install python@3.11

# Ubuntu
sudo apt update
sudo apt install python3.11 python3.11-venv
```

#### 2. Redis

**macOS**:
```bash
brew install redis
brew services start redis
```

**Ubuntu**:
```bash
sudo apt install redis-server
sudo systemctl start redis
sudo systemctl enable redis
```

**Verify Redis**:
```bash
redis-cli ping
# Should return: PONG
```

#### 3. System Dependencies

**macOS**:
```bash
brew install ffmpeg libsndfile
```

**Ubuntu**:
```bash
sudo apt install ffmpeg libsndfile1 build-essential
```

### Installation

#### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd orbi/be
```

#### 2. Install uv (Fast Package Manager)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

#### 3. Install Dependencies

```bash
# Install all dependencies
uv sync

# This will take several minutes (downloads PyTorch, etc.)
```

#### 4. Configure Environment

```bash
# Create .env file
cp .env.example .env

# Edit with your API keys
nano .env
```

#### 5. Initialize Database

```bash
# Database is created automatically on first run
# Or manually:
uv run python -c "from database import init_db; init_db()"
```

### Running Services

You need **3 terminal windows**:

**Terminal 1: Redis**
```bash
redis-server
```

**Terminal 2: Celery Worker**
```bash
cd be
uv run celery -A celery_app worker --loglevel=info
```

**Terminal 3: FastAPI**
```bash
cd be
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

---

## Configuration

### API Keys

#### HuggingFace Token

1. Go to https://huggingface.co/settings/tokens
2. Create a new token (read access is enough)
3. Accept terms at https://huggingface.co/pyannote/speaker-diarization-3.1
4. Add to `.env`: `HF_TOKEN=hf_...`

#### OpenAI API Key

1. Go to https://platform.openai.com/api-keys
2. Create a new secret key
3. Add to `.env`: `OPENAI_API_KEY=sk-...`

#### Anthropic API Key (Alternative)

1. Go to https://console.anthropic.com/
2. Create API key
3. Add to `.env`: `ANTHROPIC_API_KEY=sk-ant-...`
4. Set: `LLM_PROVIDER=anthropic`

### Model Configuration

#### Whisper (Transcription)

```env
# Trade-off: Speed vs Accuracy
WHISPER_MODEL=tiny     # Fastest, least accurate
WHISPER_MODEL=base     # Good balance (recommended)
WHISPER_MODEL=small    # Better accuracy, slower
WHISPER_MODEL=medium   # High accuracy, slow
WHISPER_MODEL=large    # Best accuracy, very slow
```

#### LLM Provider

```env
# OpenAI (default)
LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini      # Fast, cheap
# LLM_MODEL=gpt-4o          # Best quality

# Anthropic Claude
LLM_PROVIDER=anthropic
LLM_MODEL=claude-3-5-sonnet-20241022
```

#### Speaker Recognition

```env
# Similarity threshold for matching speakers
SPEAKER_SIMILARITY_THRESHOLD=0.85  # Higher = stricter matching
NEW_SPEAKER_THRESHOLD=0.70         # Lower = more lenient
```

#### Processing Limits

```env
MAX_FILE_SIZE=524288000        # 500MB in bytes
MAX_AUDIO_DURATION=3600        # 1 hour in seconds
```

---

## Testing

### Unit Tests

```bash
# Docker
make test

# Manual
cd be
uv run pytest tests/ -v
```

### Integration Tests

```bash
# With real models (slow)
uv run pytest tests/ -m integration -v

# Skip slow tests
uv run pytest tests/ -m "not slow" -v
```

### Coverage

```bash
# Docker
make test-cov

# Manual
uv run pytest tests/ --cov=. --cov-report=html
open htmlcov/index.html
```

### Manual API Test

```bash
# Health check
curl http://localhost:8000/health

# Upload file
curl -X POST "http://localhost:8000/upload" \
  -F "file=@test.mp3"

# List speakers
curl http://localhost:8000/speakers

# List recordings
curl http://localhost:8000/recordings
```

---

## Production Deployment

### Docker Production

```bash
# Build production images
make prod-build

# Start production services
make prod-up

# Check status
docker-compose ps

# View logs
make prod-logs
```

### Configuration for Production

```env
# Disable debug mode
DEBUG=False

# Use smaller models for faster processing
WHISPER_MODEL=base

# Increase worker concurrency
CELERY_CONCURRENCY=4

# Set resource limits
MAX_AUDIO_DURATION=600  # 10 minutes

# Add authentication (optional)
FLOWER_BASIC_AUTH=admin:your_secure_password
```

### Scaling

```bash
# Scale workers
docker-compose up -d --scale worker=4

# Scale API (requires load balancer)
docker-compose up -d --scale api=2
```

### Monitoring

- **Flower**: http://localhost:5555
- **Logs**: `make logs`
- **Health**: `make health`
- **Stats**: `make stats`

### Backups

```bash
# Backup database
make db-backup

# Backup data volume
docker run --rm \
  -v orbi_orbi-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/backup.tar.gz -C /data .
```

---

## Troubleshooting

### Docker Issues

**Services won't start**:
```bash
# Check ports
lsof -i :8000
lsof -i :6379

# Rebuild
make rebuild

# Check logs
make logs
```

**Out of memory**:
```bash
# Increase Docker memory
# Docker Desktop > Settings > Resources > Memory: 8GB+

# Use smaller models
WHISPER_MODEL=tiny
```

### Manual Setup Issues

**Import errors**:
```bash
# Reinstall dependencies
uv sync --reinstall
```

**Redis connection error**:
```bash
# Check Redis is running
redis-cli ping

# Start Redis
redis-server
# OR
brew services start redis
```

**Model download fails**:
```bash
# Check HF_TOKEN
echo $HF_TOKEN

# Accept model terms
# Visit: https://huggingface.co/pyannote/speaker-diarization-3.1
```

**Slow processing**:
```bash
# Use faster models
WHISPER_MODEL=tiny

# Check system resources
top
df -h
```

### Common Errors

**"No module named 'pyannote'"**:
```bash
# Reinstall dependencies
uv sync
```

**"Redis connection refused"**:
```bash
# Start Redis
redis-server
```

**"HF authentication required"**:
```bash
# Set HF_TOKEN in .env
# Accept model terms on HuggingFace
```

**"Out of memory"**:
```bash
# Reduce model size
WHISPER_MODEL=tiny
# OR increase system RAM
```

---

## Next Steps

1. **Upload a test file**: Try the `/upload` endpoint
2. **Check Flower**: Monitor task progress at port 5555
3. **View API docs**: Explore endpoints at `/docs`
4. **Run tests**: Verify everything works
5. **Customize config**: Adjust models and thresholds
6. **Deploy**: Use production docker-compose setup

## Getting Help

- **Documentation**: See [README.md](be/README.md), [DOCKER.md](DOCKER.md)
- **Tests**: Run `make test` to verify setup
- **Logs**: Check `make logs` for errors
- **Health**: Run `make health` to check services

## Quick Reference Card

```bash
# Docker
make up           # Start
make down         # Stop
make logs         # Logs
make test         # Test
make health       # Check health

# Manual
redis-server                              # Start Redis
uv run celery -A celery_app worker ...    # Start worker
uv run uvicorn main:app --reload          # Start API

# API
http://localhost:8000/docs    # API documentation
http://localhost:8000/health  # Health check
http://localhost:5555         # Flower (monitoring)
```

Happy coding! 🚀
