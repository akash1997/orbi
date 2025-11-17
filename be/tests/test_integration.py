"""Integration tests for full pipeline."""
import pytest
import numpy as np
from services.audio_processor import AudioProcessor
from services.speaker_manager import SpeakerManager
from utils.llm_client import extract_word_count, count_filler_words, calculate_speaking_pace


@pytest.mark.integration
def test_audio_processing_pipeline(sample_audio_file):
    """Test full audio processing pipeline."""
    processor = AudioProcessor()

    # Validate file
    is_valid = processor.validate_audio_file(sample_audio_file)
    assert is_valid is True

    # Process file
    audio, sr, duration = processor.process_audio_file(sample_audio_file)

    assert isinstance(audio, np.ndarray)
    assert sr == 16000
    assert duration > 0


@pytest.mark.integration
def test_speaker_identification_pipeline(db_session, test_vector_store):
    """Test speaker identification across multiple files."""
    manager = SpeakerManager(db_session, test_vector_store)

    # Simulate processing first file with a speaker
    base_embedding = np.random.randn(192).astype('float32')

    # First file - should create new speaker
    speaker_id1, is_new1 = manager.identify_or_create_speaker(
        base_embedding,
        "audio_001",
        "segment_001"
    )

    assert is_new1 is True
    initial_speaker_id = speaker_id1

    # Second file - similar embedding (same speaker)
    similar_embedding = base_embedding + np.random.randn(192).astype('float32') * 0.01
    speaker_id2, is_new2 = manager.identify_or_create_speaker(
        similar_embedding,
        "audio_002",
        "segment_001"
    )

    # Should match to same speaker
    assert speaker_id2 == initial_speaker_id
    assert is_new2 is False

    # Third file - very different embedding (new speaker)
    different_embedding = np.random.randn(192).astype('float32')
    speaker_id3, is_new3 = manager.identify_or_create_speaker(
        different_embedding,
        "audio_003",
        "segment_001"
    )

    # Should create new speaker
    assert speaker_id3 != initial_speaker_id
    assert is_new3 is True


@pytest.mark.integration
def test_word_count_analysis():
    """Test transcript analysis functions."""
    transcript = "Hello world this is a test um like you know"

    word_count = extract_word_count(transcript)
    assert word_count == 11

    filler_count = count_filler_words(transcript)
    assert filler_count >= 2  # "um", "like", "you know"

    pace = calculate_speaking_pace(transcript, duration_seconds=5.5)
    assert pace > 0
    assert pace == pytest.approx((11 / 5.5) * 60, rel=0.1)


@pytest.mark.integration
def test_end_to_end_speaker_tracking(db_session, test_vector_store):
    """Test end-to-end speaker tracking workflow."""
    from database.models import AudioFile, SpeakerAudioFile

    manager = SpeakerManager(db_session, test_vector_store)

    # Create audio files
    audio_file1 = AudioFile(filename="meeting1.mp3", filepath="/meeting1.mp3")
    audio_file2 = AudioFile(filename="meeting2.mp3", filepath="/meeting2.mp3")
    db_session.add_all([audio_file1, audio_file2])
    db_session.commit()

    # Simulate speaker appearing in first meeting
    embedding1 = np.random.randn(192).astype('float32')
    speaker_id1, _ = manager.identify_or_create_speaker(
        embedding1,
        audio_file1.id,
        "seg_1"
    )

    # Update stats for first meeting
    manager.update_speaker_stats(speaker_id1, audio_file1.id, 120.0)
    manager.create_speaker_audio_association(
        speaker_id1,
        audio_file1.id,
        120.0,
        10
    )

    # Same speaker in second meeting (similar embedding)
    embedding2 = embedding1 + np.random.randn(192).astype('float32') * 0.01
    speaker_id2, is_new = manager.identify_or_create_speaker(
        embedding2,
        audio_file2.id,
        "seg_1"
    )

    assert speaker_id2 == speaker_id1
    assert is_new is False

    # Update stats for second meeting
    manager.update_speaker_stats(speaker_id2, audio_file2.id, 90.0)
    manager.create_speaker_audio_association(
        speaker_id2,
        audio_file2.id,
        90.0,
        8
    )

    # Verify speaker stats
    speaker = manager.get_speaker(speaker_id1)
    assert speaker.total_duration_seconds == 210.0  # 120 + 90
    assert speaker.file_count == 2

    # Verify files
    files = manager.get_speaker_files(speaker_id1)
    assert len(files) == 2


@pytest.mark.integration
def test_multi_speaker_conversation(db_session, test_vector_store):
    """Test handling multiple speakers in same conversation."""
    from database.models import AudioFile, SpeakerSegment

    manager = SpeakerManager(db_session, test_vector_store)

    # Create audio file
    audio_file = AudioFile(
        filename="conversation.mp3",
        filepath="/conversation.mp3",
        duration=300.0
    )
    db_session.add(audio_file)
    db_session.commit()

    # Simulate 3 different speakers
    speakers = []
    for i in range(3):
        embedding = np.random.randn(192).astype('float32')
        speaker_id, _ = manager.identify_or_create_speaker(
            embedding,
            audio_file.id,
            f"seg_{i}"
        )
        speakers.append(speaker_id)

    # All speakers should be different
    assert len(set(speakers)) == 3

    # Create segments for each speaker
    segments = [
        (0.0, 5.0, speakers[0], "Hello everyone"),
        (5.5, 10.0, speakers[1], "Hi there"),
        (10.5, 15.0, speakers[2], "Good morning"),
        (15.5, 20.0, speakers[0], "Let's start"),
    ]

    for start, end, speaker_id, text in segments:
        segment = SpeakerSegment(
            audio_file_id=audio_file.id,
            speaker_id=speaker_id,
            start_time=start,
            end_time=end,
            duration=end - start,
            transcription=text
        )
        db_session.add(segment)

    db_session.commit()

    # Verify segments
    all_segments = db_session.query(SpeakerSegment).filter(
        SpeakerSegment.audio_file_id == audio_file.id
    ).all()

    assert len(all_segments) == 4

    # Speaker 0 should have 2 segments
    speaker0_segments = [s for s in all_segments if s.speaker_id == speakers[0]]
    assert len(speaker0_segments) == 2


@pytest.mark.integration
def test_speaker_merge_workflow(db_session, test_vector_store):
    """Test merging duplicate speaker profiles."""
    from database.models import AudioFile, SpeakerSegment

    manager = SpeakerManager(db_session, test_vector_store)

    # Create two speaker profiles (simulating duplicates)
    speaker1 = manager.create_speaker(name="John Doe")
    speaker2 = manager.create_speaker(name="John D")

    # Create audio file
    audio_file = AudioFile(filename="test.mp3", filepath="/test.mp3")
    db_session.add(audio_file)
    db_session.commit()

    # Add segments for both speakers
    segment1 = SpeakerSegment(
        audio_file_id=audio_file.id,
        speaker_id=speaker1.id,
        start_time=0.0,
        end_time=5.0,
        duration=5.0
    )
    segment2 = SpeakerSegment(
        audio_file_id=audio_file.id,
        speaker_id=speaker2.id,
        start_time=10.0,
        end_time=15.0,
        duration=5.0
    )
    db_session.add_all([segment1, segment2])

    # Update stats
    manager.update_speaker_stats(speaker1.id, audio_file.id, 50.0)
    manager.update_speaker_stats(speaker2.id, audio_file.id, 30.0)

    db_session.commit()

    # Merge speaker2 into speaker1
    success = manager.merge_speakers(speaker2.id, speaker1.id)
    assert success is True

    # Verify speaker2 is gone
    assert manager.get_speaker(speaker2.id) is None

    # Verify speaker1 has combined stats
    db_session.refresh(speaker1)
    assert speaker1.total_duration_seconds == 80.0  # 50 + 30

    # Verify all segments now point to speaker1
    all_segments = db_session.query(SpeakerSegment).filter(
        SpeakerSegment.audio_file_id == audio_file.id
    ).all()

    assert len(all_segments) == 2
    assert all(s.speaker_id == speaker1.id for s in all_segments)
