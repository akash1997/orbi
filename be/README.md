# Orbi - Speaker Intelligence API

AI-powered speaker intelligence system with automatic speaker diarization, transcription, and conversation insights.

## Features

### Automatic Processing Pipeline
When you upload an audio file, the system automatically:

1. **Speaker Diarization**: Detects who spoke when
2. **Speaker Identification**: Matches speakers to existing profiles or creates new ones
3. **Speech-to-Text**: Transcribes everything that was said
4. **Conversation Insights**: Generates summary, sentiment, action items, meetings/reminders
5. **Speaker Insights**: Analyzes individual speaking style, pace, improvements needed

### Key Capabilities

- **Automatic Speaker Recognition**: Upload multiple recordings and the system automatically identifies the same speaker across files
- **No Manual Enrollment**: Speakers are discovered and tracked automatically
- **Async Processing**: Upload returns immediately, poll for progress
- **Conversation Intelligence**: Extract action items, meetings, and key topics automatically
- **Speaker Analytics**: Track total speech time, filler words, speaking pace, and more

## Architecture

```
┌─────────────┐
│   FastAPI   │  Upload endpoint → Immediate response with job_id
└──────┬──────┘
       │
       ├─ Redis Queue ─→ Celery Workers
                              │
                              ├─ Diarization (pyannote)
                              ├─ Transcription (Whisper)
                              └─ Insights (GPT-4/Claude)
                              │
                              ├─ SQLite DB (metadata)
                              └─ FAISS (speaker embeddings)
```

## Setup

### 🐳 **Quick Start with Docker (Recommended)**

The easiest way to get started:

```bash
# 1. Clone and navigate to project
cd orbi

# 2. Setup environment file
make install
# Edit be/.env with your API keys

# 3. Start all services
make up

# 4. Access the API
open http://localhost:8000/docs
```

**That's it!** All services (API, Redis, Celery workers) are running.

See [DOCKER.md](../DOCKER.md) for complete Docker documentation.

### 📦 Manual Installation

For local development without Docker:

#### Prerequisites

- Python 3.10+
- Redis server
- HuggingFace account (for pyannote models)
- OpenAI or Anthropic API key

#### Installation

1. **Install dependencies**:
```bash
cd be
uv sync
```

2. **Install Redis** (if not already installed):

MacOS:
```bash
brew install redis
brew services start redis
```

Ubuntu/Debian:
```bash
sudo apt-get install redis-server
sudo systemctl start redis
```

3. **Create `.env` file**:
```bash
cp .env.example .env
```

Edit `.env` and add your API keys:
```env
# Required
HF_TOKEN=your_huggingface_token_here
OPENAI_API_KEY=your_openai_key_here

# Or use Anthropic Claude
# LLM_PROVIDER=anthropic
# ANTHROPIC_API_KEY=your_anthropic_key_here
```

**Get HuggingFace token**:
1. Go to https://huggingface.co/settings/tokens
2. Create a new token
3. Accept pyannote model terms at https://huggingface.co/pyannote/speaker-diarization-3.1

### Running the Application

You need to run 3 processes in separate terminals:

**Terminal 1: Redis**
```bash
redis-server
```

**Terminal 2: Celery Worker**
```bash
cd be
uv run celery -A celery_app worker --loglevel=info
```

**Terminal 3: FastAPI Server**
```bash
cd be
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at: http://localhost:8000

Interactive docs at: http://localhost:8000/docs

## Usage

### 1. Upload Audio File

```bash
curl -X POST "http://localhost:8000/upload" \
  -F "file=@meeting.mp3"
```

Response:
```json
{
  "job_id": "abc-123",
  "audio_file_id": "xyz-789",
  "filename": "meeting.mp3",
  "status": "queued",
  "message": "File uploaded successfully. Processing started."
}
```

### 2. Check Processing Status

```bash
curl "http://localhost:8000/jobs/abc-123"
```

Response:
```json
{
  "job_id": "abc-123",
  "status": "processing",
  "progress": 45,
  "current_step": "transcription",
  "started_at": "2024-01-15T10:00:00",
  "completed_at": null
}
```

### 3. Get Complete Results

Once processing is complete (status: "completed"):

```bash
curl "http://localhost:8000/recordings/xyz-789"
```

Response includes:
- Full speaker timeline with timestamps
- Transcriptions for each segment
- Conversation summary and insights
- Speaker-specific analysis
- Action items and meetings extracted

### 4. List All Speakers

```bash
curl "http://localhost:8000/speakers"
```

### 5. Get Speaker Details

```bash
curl "http://localhost:8000/speakers/{speaker_id}"
```

Shows all files where this speaker appears.

### 6. Update Speaker Name

```bash
curl -X PUT "http://localhost:8000/speakers/{speaker_id}" \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe"}'
```

### 7. Merge Duplicate Speakers

If the system created duplicate profiles for the same person:

```bash
curl -X POST "http://localhost:8000/speakers/merge" \
  -H "Content-Type: application/json" \
  -d '{
    "source_speaker_id": "speaker-to-remove",
    "target_speaker_id": "speaker-to-keep"
  }'
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/upload` | Upload audio file and start processing |
| `GET` | `/jobs/{job_id}` | Check processing job status |
| `GET` | `/recordings/{audio_file_id}` | Get complete analysis results |
| `GET` | `/recordings` | List all recordings |
| `GET` | `/speakers` | List all discovered speakers |
| `GET` | `/speakers/{speaker_id}` | Get speaker details |
| `PUT` | `/speakers/{speaker_id}` | Update speaker name/metadata |
| `POST` | `/speakers/merge` | Merge duplicate speakers |
| `DELETE` | `/speakers/{speaker_id}` | Delete speaker |

## Configuration

Edit `config.py` or use environment variables:

### Speaker Recognition Thresholds

```python
SPEAKER_SIMILARITY_THRESHOLD = 0.85  # Above this = same speaker
NEW_SPEAKER_THRESHOLD = 0.70         # Below this = definitely new
```

### Model Selection

```python
WHISPER_MODEL = "base"  # tiny/base/small/medium/large
# Larger models = better accuracy but slower

LLM_MODEL = "gpt-4o-mini"  # or "gpt-4o" for better insights
# or "claude-3-5-sonnet-20241022"
```

### Processing Limits

```python
MAX_FILE_SIZE = 500 * 1024 * 1024  # 500MB
MAX_AUDIO_DURATION = 3600  # 1 hour
```

## Project Structure

```
be/
├── main.py                    # FastAPI app
├── config.py                  # Configuration
├── celery_app.py             # Celery setup
├── database/
│   ├── models.py             # SQLAlchemy models
│   ├── session.py            # DB session
│   └── vector_store.py       # FAISS vector store
├── services/
│   ├── audio_processor.py    # Audio preprocessing
│   ├── diarization.py        # Speaker diarization
│   ├── transcription.py      # Speech-to-text
│   ├── speaker_manager.py    # Speaker CRUD
│   └── insights_generator.py # LLM insights
├── tasks/
│   └── process_audio.py      # Celery tasks
├── utils/
│   ├── audio_utils.py        # Audio utilities
│   └── llm_client.py         # LLM client
└── api/
    ├── models.py             # Pydantic models
    └── dependencies.py       # FastAPI dependencies
```

## Supported Audio Formats

- MP3
- WAV
- M4A
- FLAC
- OGG
- AAC
- WMA

## Example Response

```json
{
  "audio_file_id": "abc-123",
  "filename": "meeting.mp3",
  "duration": 180.5,
  "speakers_detected": 3,
  "speakers": [
    {
      "speaker_id": "speaker_001",
      "name": "Speaker_001",
      "is_new": false,
      "total_duration": 65.3,
      "segment_count": 12,
      "segments": [
        {
          "start": 0.0,
          "end": 5.3,
          "duration": 5.3,
          "transcription": "Good morning everyone, let's get started."
        }
      ],
      "insights": {
        "speaking_style": "Professional and clear",
        "sentiment": "positive",
        "sentiment_score": 0.75,
        "improvements": [
          "Consider varying tone for emphasis",
          "Reduce use of filler words"
        ],
        "word_count": 450,
        "filler_words_count": 8,
        "speaking_pace": 145.2
      }
    }
  ],
  "conversation_insights": {
    "summary": "Team discussed Q4 goals and budget allocation...",
    "sentiment": "positive",
    "sentiment_score": 0.8,
    "key_topics": ["Q4 planning", "Budget", "Team expansion"],
    "action_items": [
      {
        "item": "Send budget proposal to finance",
        "assigned_to": "Sarah",
        "mentioned_by": "speaker_001",
        "priority": "high"
      }
    ],
    "meetings_reminders": [
      {
        "type": "meeting",
        "description": "Follow-up call next Tuesday at 2pm",
        "date_time": "2024-01-23T14:00:00",
        "participants": ["Sarah", "John"]
      }
    ]
  }
}
```

## Troubleshooting

### Models Not Loading

Make sure you:
1. Set `HF_TOKEN` in `.env`
2. Accepted pyannote model terms on HuggingFace
3. Have enough disk space (~2GB for models)

### Slow Processing

- Use smaller Whisper model (`WHISPER_MODEL=tiny`)
- Reduce audio quality before upload
- Enable GPU if available (install `torch` with CUDA)

### Redis Connection Error

Make sure Redis is running:
```bash
redis-cli ping
# Should return: PONG
```

### Out of Memory

- Reduce `MAX_AUDIO_DURATION`
- Use smaller Whisper model
- Increase system RAM or use swap

## Performance

Approximate processing times (on CPU):

| Audio Length | Whisper Model | Processing Time |
|--------------|---------------|-----------------|
| 5 minutes    | tiny          | ~1 minute       |
| 5 minutes    | base          | ~2 minutes      |
| 30 minutes   | base          | ~10 minutes     |
| 1 hour       | medium        | ~30 minutes     |

GPU can speed this up 5-10x.

## License

MIT

## Credits

Built with:
- [pyannote.audio](https://github.com/pyannote/pyannote-audio) - Speaker diarization
- [OpenAI Whisper](https://github.com/openai/whisper) - Transcription
- [FastAPI](https://fastapi.tiangolo.com/) - Web framework
- [Celery](https://docs.celeryq.dev/) - Task queue
- [FAISS](https://github.com/facebookresearch/faiss) - Vector similarity search

## LLM Provider Configuration

The application supports multiple LLM providers for generating conversation insights and speaker analysis:

### Supported Providers

1. **OpenAI (default)**
   - Models: `gpt-4o-mini`, `gpt-4o`, `gpt-4-turbo`, etc.
   - Get API key: https://platform.openai.com/api-keys

2. **Anthropic Claude**
   - Models: `claude-3-5-sonnet-20241022`, `claude-3-opus-20240229`, etc.
   - Get API key: https://console.anthropic.com/

3. **Google Gemini** (NEW)
   - Models: `gemini-1.5-flash`, `gemini-1.5-pro`
   - Get API key: https://aistudio.google.com/app/apikey

### Configuration

Set your preferred provider and model in `.env`:

```bash
# Use OpenAI (default)
LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxx

# OR use Anthropic Claude
LLM_PROVIDER=anthropic
LLM_MODEL=claude-3-5-sonnet-20241022
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxxx

# OR use Google Gemini
LLM_PROVIDER=gemini
LLM_MODEL=gemini-1.5-flash
GEMINI_API_KEY=xxxxxxxxxxxxxxxxxxxxx
```

### Model Recommendations

| Provider | Model | Speed | Quality | Cost | Best For |
|----------|-------|-------|---------|------|----------|
| Gemini | gemini-1.5-flash | ⚡⚡⚡ | ⭐⭐⭐ | 💰 | Fast, cost-effective insights |
| OpenAI | gpt-4o-mini | ⚡⚡ | ⭐⭐⭐⭐ | 💰💰 | Balanced performance |
| Anthropic | claude-3-5-sonnet | ⚡⚡ | ⭐⭐⭐⭐⭐ | 💰💰💰 | Highest quality analysis |
| Gemini | gemini-1.5-pro | ⚡ | ⭐⭐⭐⭐⭐ | 💰💰 | Complex conversations |

### Features by Provider

All providers support:
- ✅ Conversation summarization
- ✅ Sentiment analysis
- ✅ Key topic extraction
- ✅ Action item detection
- ✅ Meeting reminder extraction
- ✅ Speaker-specific insights
- ✅ Communication style analysis
- ✅ JSON-formatted responses


## Pipeline-Specific Model Configuration

You can configure different models for each pipeline stage to optimize for cost, speed, or quality:

### Pipeline Stages

1. **Diarization Pipeline**: Speaker detection and segmentation
   - Model: `DIARIZATION_MODEL` (pyannote)
   - Cannot be changed per-conversation (fixed model)

2. **Transcription Pipeline**: Speech-to-text conversion
   - Model: `WHISPER_MODEL` (tiny/base/small/medium/large)
   - Cannot be changed per-conversation (fixed model)

3. **Conversation Insights Pipeline**: Overall conversation analysis
   - Provider: `CONVERSATION_LLM_PROVIDER` (openai/anthropic/gemini)
   - Model: `CONVERSATION_LLM_MODEL`
   - Generates: Summary, sentiment, action items, meeting reminders

4. **Speaker Insights Pipeline**: Individual speaker analysis
   - Provider: `SPEAKER_LLM_PROVIDER` (openai/anthropic/gemini)
   - Model: `SPEAKER_LLM_MODEL`
   - Generates: Speaking style, improvements, communication effectiveness

### Configuration Examples

**Example 1: Use different providers for different pipelines**
```bash
# Default LLM
LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini

# Use Gemini Flash for fast conversation summaries
CONVERSATION_LLM_PROVIDER=gemini
CONVERSATION_LLM_MODEL=gemini-1.5-flash

# Use Claude for detailed speaker coaching
SPEAKER_LLM_PROVIDER=anthropic
SPEAKER_LLM_MODEL=claude-3-5-sonnet-20241022
```

**Example 2: Cost-optimized setup**
```bash
# Use Gemini Flash for everything (most cost-effective)
LLM_PROVIDER=gemini
LLM_MODEL=gemini-1.5-flash
CONVERSATION_LLM_PROVIDER=gemini
CONVERSATION_LLM_MODEL=gemini-1.5-flash
SPEAKER_LLM_PROVIDER=gemini
SPEAKER_LLM_MODEL=gemini-1.5-flash
```

**Example 3: Quality-optimized setup**
```bash
# Use Claude Sonnet for everything (highest quality)
LLM_PROVIDER=anthropic
LLM_MODEL=claude-3-5-sonnet-20241022
# No need to set pipeline-specific configs, defaults will be used
```

**Example 4: Balanced setup**
```bash
# Use GPT-4o-mini as default
LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini

# Use Gemini Pro for complex conversation analysis
CONVERSATION_LLM_PROVIDER=gemini
CONVERSATION_LLM_MODEL=gemini-1.5-pro

# Keep default for speaker insights
# (SPEAKER_LLM_PROVIDER and SPEAKER_LLM_MODEL not set, will use defaults)
```

### Cost Comparison

Approximate costs per 1M tokens (as of 2024):

| Provider | Model | Input | Output | Best For |
|----------|-------|-------|--------|----------|
| Gemini | gemini-1.5-flash | $0.075 | $0.30 | High volume, fast processing |
| OpenAI | gpt-4o-mini | $0.15 | $0.60 | Balanced cost/quality |
| Gemini | gemini-1.5-pro | $1.25 | $5.00 | Complex conversations |
| Anthropic | claude-3-5-sonnet | $3.00 | $15.00 | Highest quality analysis |

### When to Use Pipeline-Specific Configuration

- **High Volume**: Use Gemini Flash for conversation insights (cheaper, faster)
- **Detailed Coaching**: Use Claude for speaker insights (better feedback quality)
- **Budget Constraints**: Use Gemini Flash for everything
- **Quality Priority**: Use Claude for everything
- **Balanced**: Use GPT-4o-mini as default, Gemini Pro for complex tasks

### Transcription Model Selection

Configure Whisper model based on your needs:

```bash
# Fastest, lowest quality (good for testing)
WHISPER_MODEL=tiny

# Fast, decent quality (recommended for most use cases)
WHISPER_MODEL=base

# Balanced (default)
WHISPER_MODEL=small

# High quality (slower)
WHISPER_MODEL=medium

# Highest quality (slowest, requires more memory)
WHISPER_MODEL=large
```

