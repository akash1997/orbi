# Quick Start Guide

Get the Orbi Speaker Intelligence API up and running in 5 minutes.

## Prerequisites Check

```bash
# Check Python version (need 3.10+)
python3 --version

# Check if Redis is installed
redis-cli --version

# Check if uv is installed
uv --version
```

## 1. Install Dependencies

```bash
cd be

# Install all Python dependencies
uv sync

# This will install:
# - FastAPI & Uvicorn (web server)
# - Celery & Redis (async tasks)
# - PyAnnote & Whisper (ML models)
# - OpenAI/Anthropic (LLM integration)
# - And many more...
```

## 2. Setup Environment Variables

```bash
# Copy example file
cp .env.example .env

# Edit .env and add your API keys
nano .env  # or use your favorite editor
```

**Required API Keys:**

1. **HuggingFace Token** (for pyannote models):
   - Go to: https://huggingface.co/settings/tokens
   - Create a new token
   - Accept model terms: https://huggingface.co/pyannote/speaker-diarization-3.1

2. **OpenAI API Key** (for conversation insights):
   - Go to: https://platform.openai.com/api-keys
   - Create a new API key

Your `.env` should look like:
```env
HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxx
```

## 3. Start Redis

**MacOS:**
```bash
brew services start redis
```

**Linux:**
```bash
sudo systemctl start redis
```

**Or run manually:**
```bash
redis-server
```

## 4. Start the Application

Open **3 terminal windows**:

### Terminal 1: Celery Worker
```bash
cd be
uv run celery -A celery_app worker --loglevel=info
```

### Terminal 2: FastAPI Server
```bash
cd be
uv run uvicorn main:app --reload
```

### Terminal 3: Test it!
```bash
# Check if server is running
curl http://localhost:8000/health

# Should return: {"status":"healthy","version":"0.1.0"}
```

## 5. Test with Sample Audio

```bash
# Upload an audio file (replace with your file)
curl -X POST "http://localhost:8000/upload" \
  -F "file=@/path/to/your/audio.mp3"

# You'll get back a job_id, like:
# {"job_id":"abc-123","audio_file_id":"xyz-789",...}

# Check processing status
curl "http://localhost:8000/jobs/abc-123"

# Once status is "completed", get the results
curl "http://localhost:8000/recordings/xyz-789"
```

## 6. View in Browser

Open: http://localhost:8000/docs

This opens the interactive API documentation where you can:
- Upload files via web UI
- Test all endpoints
- See response schemas

## Common Issues

### "Module not found" error
```bash
# Make sure you're using uv to run commands
uv run uvicorn main:app --reload
```

### Redis connection error
```bash
# Check if Redis is running
redis-cli ping
# Should return: PONG

# If not, start it
brew services start redis  # MacOS
sudo systemctl start redis  # Linux
```

### HuggingFace authentication error
- Make sure you accepted the model terms at https://huggingface.co/pyannote/speaker-diarization-3.1
- Check that `HF_TOKEN` is set in `.env`

### Slow processing
For faster testing, use smaller Whisper model:
```env
WHISPER_MODEL=tiny
```

## Next Steps

1. **Upload multiple files** to see automatic speaker recognition across files
2. **Set speaker names**: `PUT /speakers/{speaker_id}` with `{"name": "John Doe"}`
3. **View all speakers**: `GET /speakers`
4. **Check conversation insights** for action items and meeting notes

## Development Tips

**Auto-reload on code changes:**
Both Celery and Uvicorn support auto-reload:
```bash
# Celery with auto-reload
uv run celery -A celery_app worker --loglevel=info --autoreload

# Uvicorn with auto-reload (already enabled with --reload flag)
uv run uvicorn main:app --reload
```

**View logs:**
All logs go to stdout. For production, configure proper logging in `config.py`.

**Database location:**
SQLite database is created at `be/orbi.db`. To reset:
```bash
rm orbi.db
# Restart the server to recreate
```

## Performance Tips

For faster processing:

1. **Use GPU** (if available):
   ```bash
   # Install PyTorch with CUDA
   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
   ```

2. **Use smaller models**:
   ```env
   WHISPER_MODEL=tiny  # or base
   ```

3. **Limit audio duration**:
   ```env
   MAX_AUDIO_DURATION=600  # 10 minutes max
   ```

## Production Deployment

For production, use:
- PostgreSQL instead of SQLite
- Separate Redis instances for broker and backend
- Multiple Celery workers
- Nginx as reverse proxy
- Docker containers for easy deployment

See [README.md](README.md) for more details.

## Support

- Issues: https://github.com/your-repo/orbi/issues
- Documentation: http://localhost:8000/docs
- Full README: [README.md](README.md)
