# Multi-stage Dockerfile for Orbi Speaker Intelligence API
FROM python:3.11-slim as base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy dependency files
COPY pyproject.toml ./

# Upgrade pip and install dependencies directly from pyproject.toml
# Install torch and torchaudio first with compatible versions for pyannote.audio
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    torch==2.3.0 \
    torchaudio==2.3.0 \
    torchvision==0.18.0 && \
    pip install --no-cache-dir \
    fastapi>=0.115.0 \
    uvicorn[standard]>=0.32.0 \
    python-multipart>=0.0.12 \
    pydantic>=2.0.0 \
    pydantic-settings>=2.0.0 \
    celery>=5.3.0 \
    redis>=5.0.0 \
    sqlalchemy>=2.0.0 \
    alembic>=1.12.0 \
    librosa>=0.10.0 \
    soundfile>=0.12.0 \
    pydub>=0.25.0 \
    audioread>=3.0.0 \
    pyannote.audio>=3.1.0 \
    speechbrain>=0.5.0 \
    transformers>=4.30.0 \
    openai-whisper>=20231117 \
    faiss-cpu>=1.7.4 \
    numpy>=1.24.0 \
    openai>=1.0.0 \
    anthropic>=0.7.0 \
    google-generativeai>=0.3.0 \
    python-dotenv>=1.0.0 \
    python-jose[cryptography]>=3.3.0 \
    flower>=2.0.0

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

# Create necessary directories and set ownership
RUN mkdir -p data/recordings data/models_cache data/speaker_embeddings logs && \
    chown -R appuser:appuser /app

USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default command (can be overridden in docker-compose)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
