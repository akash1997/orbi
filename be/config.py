"""Application configuration settings."""
from pydantic_settings import BaseSettings, SettingsConfigDict
from pathlib import Path


class Settings(BaseSettings):
    """Application settings with environment variable support."""

    # App Info
    APP_NAME: str = "Orbi - Speaker Intelligence API"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = True

    # Directories
    BASE_DIR: Path = Path(__file__).parent
    UPLOAD_DIR: Path = BASE_DIR / "recordings"
    MODELS_CACHE_DIR: Path = BASE_DIR / "models_cache"
    VECTOR_DB_PATH: Path = BASE_DIR / "speaker_embeddings"

    # Database
    DATABASE_URL: str = "sqlite:///./orbi.db"

    # Redis & Celery
    REDIS_URL: str = "redis://localhost:6379/0"
    CELERY_BROKER_URL: str = "redis://localhost:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/0"

    # File Upload
    MAX_FILE_SIZE: int = 500 * 1024 * 1024  # 500MB
    ALLOWED_EXTENSIONS: set = {".mp3", ".wav", ".m4a", ".flac", ".ogg", ".aac", ".wma"}

    # Speaker Recognition
    SPEAKER_SIMILARITY_THRESHOLD: float = 0.85  # Above this = match existing speaker
    NEW_SPEAKER_THRESHOLD: float = 0.70  # Below this = definitely new speaker
    EMBEDDING_DIMENSION: int = 192  # pyannote embedding dimension

    # Models
    DIARIZATION_MODEL: str = "pyannote/speaker-diarization-3.1"
    SPEAKER_EMBEDDING_MODEL: str = "pyannote/wespeaker-voxceleb-resnet34-LM"
    WHISPER_MODEL: str = "base"  # tiny/base/small/medium/large

    # LLM API Keys
    OPENAI_API_KEY: str = ""
    ANTHROPIC_API_KEY: str = ""
    LLM_PROVIDER: str = "openai"  # "openai" or "anthropic"
    LLM_MODEL: str = "gpt-4o-mini"  # or "claude-3-5-sonnet-20241022"

    # HuggingFace (required for pyannote)
    HF_TOKEN: str = ""

    # Processing
    MAX_AUDIO_DURATION: int = 3600  # 1 hour max
    VAD_ONSET: float = 0.5
    VAD_OFFSET: float = 0.363

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Create directories if they don't exist
        self.UPLOAD_DIR.mkdir(exist_ok=True)
        self.MODELS_CACHE_DIR.mkdir(exist_ok=True)
        self.VECTOR_DB_PATH.mkdir(exist_ok=True)


# Global settings instance
settings = Settings()
