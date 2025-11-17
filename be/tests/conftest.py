"""Pytest fixtures and configuration."""
import pytest
import numpy as np
from pathlib import Path
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient
import tempfile
import shutil
import sys
from unittest.mock import MagicMock

# Mock heavy ML libraries to speed up tests
sys.modules['pyannote'] = MagicMock()
sys.modules['pyannote.audio'] = MagicMock()
sys.modules['pyannote.audio.pipelines'] = MagicMock()
sys.modules['pyannote.audio.pipelines.speaker_verification'] = MagicMock()
sys.modules['pyannote.core'] = MagicMock()
sys.modules['speechbrain'] = MagicMock()
sys.modules['speechbrain.inference'] = MagicMock()
sys.modules['whisper'] = MagicMock()

from database.models import Base
from database.vector_store import VectorStore
from config import settings


@pytest.fixture(scope="session")
def test_db_engine():
    """Create a test database engine."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    yield engine
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def db_session(test_db_engine):
    """Create a new database session for a test."""
    SessionLocal = sessionmaker(bind=test_db_engine)
    session = SessionLocal()
    yield session
    session.rollback()
    session.close()


@pytest.fixture(scope="function")
def test_vector_store(tmp_path):
    """Create a test vector store."""
    vector_store = VectorStore(dimension=192, index_path=tmp_path / "test_vectors")
    yield vector_store


@pytest.fixture(scope="function")
def test_upload_dir(tmp_path):
    """Create a temporary upload directory."""
    upload_dir = tmp_path / "test_recordings"
    upload_dir.mkdir()

    # Temporarily override settings
    original_upload_dir = settings.UPLOAD_DIR
    settings.UPLOAD_DIR = upload_dir

    yield upload_dir

    # Restore original
    settings.UPLOAD_DIR = original_upload_dir


@pytest.fixture(scope="function")
def client(db_session, test_upload_dir):
    """Create a test client."""
    # Import app here after mocks are in place
    from main import app

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    from api.dependencies import get_db
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()


@pytest.fixture
def sample_audio_array():
    """Generate a sample audio array (1 second of sine wave)."""
    sample_rate = 16000
    duration = 1.0
    frequency = 440  # A4 note

    t = np.linspace(0, duration, int(sample_rate * duration))
    audio = np.sin(2 * np.pi * frequency * t).astype(np.float32)

    return audio, sample_rate


@pytest.fixture
def sample_audio_file(tmp_path, sample_audio_array):
    """Create a sample audio file."""
    import soundfile as sf

    audio, sr = sample_audio_array
    file_path = tmp_path / "test_audio.wav"
    sf.write(str(file_path), audio, sr)

    return file_path


@pytest.fixture
def sample_embedding():
    """Generate a sample speaker embedding."""
    return np.random.randn(192).astype('float32')


@pytest.fixture
def mock_speaker_data():
    """Mock speaker data for testing."""
    return {
        "name": "Test Speaker",
        "segments": [
            {"start": 0.0, "end": 5.0, "transcription": "Hello world"},
            {"start": 5.5, "end": 10.0, "transcription": "This is a test"},
        ]
    }


@pytest.fixture
def mock_conversation_transcript():
    """Mock conversation transcript."""
    return """
    Speaker_001: Good morning everyone, let's start the meeting.
    Speaker_002: Thanks for organizing this. I have a few agenda items to discuss.
    Speaker_001: Great. Let's start with the Q4 planning.
    Speaker_002: We need to finalize the budget by next Friday.
    Speaker_001: I'll send the proposal to finance tomorrow.
    """


@pytest.fixture
def mock_llm_insights():
    """Mock LLM-generated insights."""
    return {
        "summary": "Team meeting discussing Q4 planning and budget finalization.",
        "sentiment_overall": "positive",
        "sentiment_score": 0.75,
        "key_topics": ["Q4 planning", "Budget", "Finance"],
        "action_items": [
            {
                "item": "Send budget proposal to finance",
                "assigned_to": "Speaker_001",
                "mentioned_by": "speaker_001",
                "priority": "high"
            }
        ],
        "meetings_reminders": [
            {
                "type": "deadline",
                "description": "Finalize budget",
                "date_time": "next Friday",
                "participants": []
            }
        ]
    }


@pytest.fixture
def mock_speaker_insights():
    """Mock speaker-specific insights."""
    return {
        "speaking_style": "Professional and clear",
        "sentiment": "positive",
        "sentiment_score": 0.8,
        "strengths": ["Clear communication", "Good organization"],
        "improvements": [
            "Consider varying tone for emphasis",
            "Reduce use of filler words"
        ],
        "notable_patterns": ["Uses formal language"],
        "communication_effectiveness": 8
    }
