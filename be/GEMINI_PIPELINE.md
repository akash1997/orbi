# Gemini Audio Processing Pipeline

## Overview

Orbi now supports two audio processing pipelines:

1. **Traditional Pipeline** (default): Uses specialized models
   - pyannote.audio for speaker diarization
   - OpenAI Whisper for transcription
   - LLM (OpenAI/Anthropic/Gemini) for insights generation

2. **Gemini Pipeline**: Uses only Google Gemini API
   - Single API call for diarization, transcription, and insights
   - Simpler setup, no HuggingFace token required
   - More cost-effective for small-medium audio files
   - Requires only GEMINI_API_KEY

## Quick Start with Gemini Pipeline

### 1. Configure Environment

Edit your `.env` file:

```bash
# Set pipeline to Gemini
AUDIO_PIPELINE=gemini

# Add your Gemini API key
GEMINI_API_KEY=your_gemini_api_key_here

# Optional: Other API keys not required for Gemini pipeline
# HF_TOKEN not needed
```

### 2. Start Services

```bash
make up
```

### 3. Upload Audio

The system will automatically use the Gemini pipeline for all audio processing.

## Pipeline Comparison

| Feature | Traditional Pipeline | Gemini Pipeline |
|---------|---------------------|-----------------|
| **Diarization** | pyannote.audio | Gemini 1.5 Pro |
| **Transcription** | OpenAI Whisper | Gemini 1.5 Pro |
| **Insights** | LLM (OpenAI/Anthropic/Gemini) | Gemini 1.5 Pro |
| **API Keys Required** | HF_TOKEN + (OPENAI/ANTHROPIC/GEMINI) | GEMINI_API_KEY only |
| **Setup Complexity** | High (gated models, agreements) | Low (single API key) |
| **Processing Steps** | 3 separate steps | 1 unified step |
| **Model Downloads** | ~2GB (pyannote + Whisper) | None (cloud-based) |
| **Docker Image Size** | Larger | Same base |
| **Speaker Embeddings** | Real voice embeddings | Synthetic embeddings |
| **Accuracy** | High (specialized models) | Good (multimodal general model) |
| **Cost** | Compute cost | API cost per audio minute |
| **Best For** | Production, high accuracy needs | Quick setup, cost-effective |

## Configuration Options

### .env File

```bash
# Audio Processing Pipeline Selection
AUDIO_PIPELINE=gemini  # or "traditional"

# Gemini API Key (required for Gemini pipeline)
GEMINI_API_KEY=your_gemini_api_key_here

# Gemini Audio Model (IMPORTANT: Only Pro models support audio)
GEMINI_AUDIO_MODEL=gemini-1.5-pro  # or gemini-1.5-pro-002
# Note: gemini-1.5-flash does NOT support audio files

# Traditional Pipeline Settings (not needed for Gemini)
# HF_TOKEN=your_huggingface_token
# WHISPER_MODEL=base
# DIARIZATION_MODEL=pyannote/speaker-diarization-3.1
# SPEAKER_EMBEDDING_MODEL=pyannote/wespeaker-voxceleb-resnet34-LM
```

### Switching Between Pipelines

To switch from Gemini to Traditional:

```bash
# Stop services
make down

# Edit .env
AUDIO_PIPELINE=traditional
HF_TOKEN=your_huggingface_token_here

# Restart services
make up
```

## How the Gemini Pipeline Works

### Architecture

```
Audio File
    |
    v
[Gemini 1.5 Pro Multimodal API]
    |
    +-- Speaker Diarization
    |   (Voice analysis, speaker separation)
    |
    +-- Transcription
    |   (Speech-to-text for each segment)
    |
    +-- Speaker Insights
    |   (Style, sentiment, metrics)
    |
    +-- Conversation Insights
    |   (Summary, topics, action items)
    |
    v
Database Storage
```

### Processing Steps

1. **Upload**: Audio file is uploaded to Gemini File API
2. **Analysis**: Gemini analyzes the entire audio in one pass
   - Identifies unique speakers by voice characteristics
   - Timestamps each speaker segment
   - Transcribes all speech
   - Analyzes speaking patterns and metrics
   - Generates conversation-level insights
3. **Formatting**: Results are formatted to match traditional pipeline structure
4. **Speaker Identification**: Synthetic embeddings are created for speaker matching
5. **Storage**: All data is saved to database (same schema as traditional pipeline)

### Synthetic Embeddings

Since Gemini doesn't provide voice embeddings, the system generates synthetic embeddings:
- Deterministic: Same speaker ID always gets the same embedding
- Unique: Each speaker gets a distinct embedding
- Normalized: Compatible with existing FAISS vector database
- Purpose: Allows speaker matching across recordings

## API Response Format

Both pipelines return identical response formats:

```json
{
  "success": true,
  "audio_file_id": "uuid",
  "pipeline": "gemini",  // or "traditional"
  "speakers_detected": 2,
  "new_speakers": ["speaker_id_1", "speaker_id_2"],
  "segments_count": 45
}
```

## Cost Comparison

### Traditional Pipeline
- **Setup Cost**: Time investment (agreements, tokens, model downloads)
- **Runtime Cost**: Compute resources (CPU/GPU)
- **Per-file Cost**: ~$0 (using local compute)
- **Best for**: High-volume processing, privacy-sensitive data

### Gemini Pipeline
- **Setup Cost**: Minimal (just API key)
- **Runtime Cost**: API calls to Gemini
- **Per-file Cost**: ~$0.02-0.10 per minute of audio (Gemini 1.5 Pro pricing)
- **Best for**: Low-volume processing, quick setup, demos

Example: 10-minute conversation
- Traditional: $0 (uses local GPU/CPU)
- Gemini: ~$0.20-1.00 (depends on Gemini pricing)

## Limitations

### Gemini Pipeline Limitations

1. **Network Dependency**: Requires internet connection
2. **Privacy**: Audio is sent to Google's servers
3. **Rate Limits**: Subject to Gemini API rate limits
4. **Audio Size**: Limited by Gemini File API (typically up to 2GB)
5. **Accuracy**: May be less accurate than specialized models for:
   - Very similar voices
   - Heavy accents
   - Background noise
   - Multiple simultaneous speakers

### Traditional Pipeline Limitations

1. **Setup Complexity**: Requires HuggingFace account and model agreements
2. **Resource Usage**: Requires significant CPU/GPU and memory
3. **Model Size**: ~2GB of model downloads
4. **Dependencies**: More complex dependency management

## Troubleshooting

### "GEMINI_API_KEY is required" Error

```bash
# Make sure GEMINI_API_KEY is set in .env
echo "GEMINI_API_KEY=your_key_here" >> be/.env

# Restart services
make restart
```

### "Gemini failed to process audio" Error

- Check audio file format (should be MP3, WAV, M4A, etc.)
- Verify file isn't corrupted
- Check file size (should be under 2GB)
- Verify Gemini API key is valid

### Poor Diarization Quality

- Gemini may struggle with:
  - Very similar voices
  - Poor audio quality
  - Multiple speakers talking simultaneously

Consider using traditional pipeline for better accuracy in these cases.

### API Rate Limits

If you hit rate limits:
- Reduce concurrent processing
- Add retry logic
- Consider traditional pipeline for high-volume processing

## Best Practices

### When to Use Gemini Pipeline

- **Development**: Quick setup for testing
- **Demos**: No model downloads required
- **Small Scale**: Processing occasional files
- **No GPU**: When compute resources are limited
- **Quick Start**: Getting started without complex setup

### When to Use Traditional Pipeline

- **Production**: High-volume, consistent processing
- **Privacy**: Data cannot leave premises
- **Accuracy**: Need highest quality diarization
- **Cost**: Processing many hours of audio
- **Offline**: No reliable internet connection

## Advanced Configuration

### Custom Prompts

To modify the Gemini analysis prompt, edit:
```python
# be/services/gemini_audio_processor.py
def _build_comprehensive_prompt(self) -> str:
    # Customize prompt here
```

### Response Parsing

To handle custom response formats:
```python
# be/services/gemini_audio_processor.py
def _parse_gemini_response(self, content: str) -> Dict[str, Any]:
    # Customize parsing here
```

## Development

### Testing Gemini Pipeline

```python
# Test with sample audio
from services.gemini_audio_processor import GeminiAudioProcessor

processor = GeminiAudioProcessor()
result = processor.process_audio_file("test_audio.mp3")
print(result)
```

### Adding New Features

The Gemini pipeline can be extended to:
- Detect languages
- Identify emotions
- Extract keywords
- Generate summaries with different styles
- Detect topics in real-time

Simply modify the prompt in `_build_comprehensive_prompt()`.

## Support

For issues specific to:
- **Gemini API**: Check Google AI documentation
- **Traditional Pipeline**: Check pyannote.audio and Whisper docs
- **Integration**: Open an issue in the project repository

## Future Enhancements

Potential improvements:
- Streaming audio processing
- Real-time speaker identification
- Multi-language support
- Custom speaker naming
- Voice characteristic analysis
- Emotion detection
- Advanced sentiment analysis
