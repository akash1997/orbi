"""Tests for speaker manager service."""
import pytest
import numpy as np
from services.speaker_manager import SpeakerManager
from database.models import Speaker, AudioFile, SpeakerAudioFile


@pytest.mark.unit
def test_create_speaker(db_session, test_vector_store):
    """Test creating a new speaker."""
    manager = SpeakerManager(db_session, test_vector_store)

    speaker = manager.create_speaker(name="John Doe")

    assert speaker.id is not None
    assert speaker.name == "John Doe"
    assert speaker.total_duration_seconds == 0.0


@pytest.mark.unit
def test_create_speaker_default_name(db_session, test_vector_store):
    """Test creating speaker with default name."""
    manager = SpeakerManager(db_session, test_vector_store)

    speaker = manager.create_speaker()

    assert speaker.name.startswith("Speaker_")


@pytest.mark.unit
def test_get_speaker(db_session, test_vector_store):
    """Test retrieving a speaker."""
    manager = SpeakerManager(db_session, test_vector_store)

    created = manager.create_speaker(name="Test Speaker")
    retrieved = manager.get_speaker(created.id)

    assert retrieved is not None
    assert retrieved.id == created.id
    assert retrieved.name == "Test Speaker"


@pytest.mark.unit
def test_get_nonexistent_speaker(db_session, test_vector_store):
    """Test retrieving non-existent speaker."""
    manager = SpeakerManager(db_session, test_vector_store)

    result = manager.get_speaker("nonexistent_id")

    assert result is None


@pytest.mark.unit
def test_list_speakers(db_session, test_vector_store):
    """Test listing speakers."""
    manager = SpeakerManager(db_session, test_vector_store)

    # Create multiple speakers
    for i in range(5):
        manager.create_speaker(name=f"Speaker {i}")

    speakers = manager.list_speakers(limit=10)

    assert len(speakers) == 5


@pytest.mark.unit
def test_update_speaker(db_session, test_vector_store):
    """Test updating speaker information."""
    manager = SpeakerManager(db_session, test_vector_store)

    speaker = manager.create_speaker(name="Original Name")
    updated = manager.update_speaker(
        speaker.id,
        name="Updated Name",
        metadata={"role": "manager"}
    )

    assert updated.name == "Updated Name"
    assert updated.metadata["role"] == "manager"


@pytest.mark.unit
def test_identify_or_create_speaker_new(db_session, test_vector_store):
    """Test identifying or creating a new speaker."""
    manager = SpeakerManager(db_session, test_vector_store)

    embedding = np.random.randn(192).astype('float32')
    speaker_id, is_new = manager.identify_or_create_speaker(
        embedding,
        "audio_001",
        "segment_001"
    )

    assert speaker_id is not None
    assert is_new is True
    assert test_vector_store.get_total_embeddings() == 1


@pytest.mark.unit
def test_identify_or_create_speaker_existing(db_session, test_vector_store):
    """Test identifying existing speaker."""
    manager = SpeakerManager(db_session, test_vector_store)

    # Add first embedding
    embedding1 = np.random.randn(192).astype('float32')
    speaker_id1, is_new1 = manager.identify_or_create_speaker(
        embedding1,
        "audio_001",
        "segment_001"
    )

    assert is_new1 is True

    # Add very similar embedding (should match)
    embedding2 = embedding1 + np.random.randn(192).astype('float32') * 0.01
    speaker_id2, is_new2 = manager.identify_or_create_speaker(
        embedding2,
        "audio_001",
        "segment_002"
    )

    assert speaker_id2 == speaker_id1
    assert is_new2 is False


@pytest.mark.unit
def test_update_speaker_stats(db_session, test_vector_store):
    """Test updating speaker statistics."""
    manager = SpeakerManager(db_session, test_vector_store)

    # Create speaker and audio file
    speaker = manager.create_speaker()
    audio_file = AudioFile(filename="test.mp3", filepath="/test.mp3")
    db_session.add(audio_file)
    db_session.commit()

    # Update stats
    manager.update_speaker_stats(speaker.id, audio_file.id, duration=120.5)

    # Refresh and check
    db_session.refresh(speaker)
    assert speaker.total_duration_seconds == 120.5
    assert speaker.file_count == 1


@pytest.mark.unit
def test_create_speaker_audio_association(db_session, test_vector_store):
    """Test creating speaker-audio association."""
    manager = SpeakerManager(db_session, test_vector_store)

    # Create dependencies
    speaker = manager.create_speaker()
    audio_file = AudioFile(filename="meeting.mp3", filepath="/meeting.mp3")
    db_session.add(audio_file)
    db_session.commit()

    # Create association
    assoc = manager.create_speaker_audio_association(
        speaker.id,
        audio_file.id,
        total_duration=150.0,
        segment_count=12
    )

    assert assoc.speaker_id == speaker.id
    assert assoc.audio_file_id == audio_file.id
    assert assoc.total_speech_duration == 150.0
    assert assoc.segment_count == 12


@pytest.mark.unit
def test_get_speaker_files(db_session, test_vector_store):
    """Test getting all files for a speaker."""
    manager = SpeakerManager(db_session, test_vector_store)

    # Create speaker
    speaker = manager.create_speaker()

    # Create multiple audio files
    for i in range(3):
        audio_file = AudioFile(
            filename=f"file_{i}.mp3",
            filepath=f"/path/to/file_{i}.mp3"
        )
        db_session.add(audio_file)
        db_session.flush()

        manager.create_speaker_audio_association(
            speaker.id,
            audio_file.id,
            total_duration=100.0 + i * 10,
            segment_count=10 + i
        )

    db_session.commit()

    # Get files
    files = manager.get_speaker_files(speaker.id)

    assert len(files) == 3
    assert files[0]["duration_in_file"] == 100.0
    assert files[1]["duration_in_file"] == 110.0
    assert files[2]["duration_in_file"] == 120.0


@pytest.mark.unit
def test_merge_speakers(db_session, test_vector_store):
    """Test merging two speakers."""
    manager = SpeakerManager(db_session, test_vector_store)

    # Create two speakers
    speaker1 = manager.create_speaker(name="Speaker 1")
    speaker2 = manager.create_speaker(name="Speaker 2")

    # Add data for speaker1
    audio_file1 = AudioFile(filename="file1.mp3", filepath="/file1.mp3")
    db_session.add(audio_file1)
    db_session.flush()

    manager.create_speaker_audio_association(
        speaker1.id, audio_file1.id, 100.0, 10
    )

    manager.update_speaker_stats(speaker1.id, audio_file1.id, 100.0)

    db_session.commit()

    # Merge speaker1 into speaker2
    success = manager.merge_speakers(speaker1.id, speaker2.id)

    assert success is True

    # speaker1 should be deleted
    assert manager.get_speaker(speaker1.id) is None

    # speaker2 should have inherited data
    db_session.refresh(speaker2)
    assert speaker2.total_duration_seconds == 100.0


@pytest.mark.unit
def test_delete_speaker(db_session, test_vector_store):
    """Test deleting a speaker."""
    manager = SpeakerManager(db_session, test_vector_store)

    speaker = manager.create_speaker()
    speaker_id = speaker.id

    success = manager.delete_speaker(speaker_id)

    assert success is True
    assert manager.get_speaker(speaker_id) is None
