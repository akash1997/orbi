"""Tests for database models and operations."""
import pytest
from datetime import datetime
from database.models import (
    Speaker,
    AudioFile,
    SpeakerAudioFile,
    SpeakerSegment,
    ConversationInsight,
    SpeakerInsight,
    ProcessingJob,
    ProcessingStatus
)


@pytest.mark.unit
def test_create_speaker(db_session):
    """Test creating a speaker."""
    speaker = Speaker(name="Test Speaker")
    db_session.add(speaker)
    db_session.commit()

    assert speaker.id is not None
    assert speaker.name == "Test Speaker"
    assert speaker.total_duration_seconds == 0.0
    assert speaker.file_count == 0
    assert isinstance(speaker.created_at, datetime)


@pytest.mark.unit
def test_create_audio_file(db_session):
    """Test creating an audio file."""
    audio_file = AudioFile(
        filename="test.mp3",
        filepath="/path/to/test.mp3",
        duration=120.5,
        format=".mp3"
    )
    db_session.add(audio_file)
    db_session.commit()

    assert audio_file.id is not None
    assert audio_file.filename == "test.mp3"
    assert audio_file.duration == 120.5
    assert audio_file.processing_status == ProcessingStatus.QUEUED


@pytest.mark.unit
def test_speaker_audio_file_association(db_session):
    """Test speaker-audio file association."""
    # Create speaker
    speaker = Speaker(name="Speaker 1")
    db_session.add(speaker)

    # Create audio file
    audio_file = AudioFile(
        filename="meeting.mp3",
        filepath="/path/to/meeting.mp3",
        duration=600.0
    )
    db_session.add(audio_file)
    db_session.commit()

    # Create association
    assoc = SpeakerAudioFile(
        speaker_id=speaker.id,
        audio_file_id=audio_file.id,
        total_speech_duration=250.0,
        segment_count=15
    )
    db_session.add(assoc)
    db_session.commit()

    assert assoc.id is not None
    assert assoc.total_speech_duration == 250.0
    assert assoc.segment_count == 15


@pytest.mark.unit
def test_speaker_segment(db_session):
    """Test speaker segment creation."""
    # Create dependencies
    speaker = Speaker(name="Speaker 1")
    audio_file = AudioFile(filename="test.mp3", filepath="/test.mp3")
    db_session.add_all([speaker, audio_file])
    db_session.commit()

    # Create segment
    segment = SpeakerSegment(
        audio_file_id=audio_file.id,
        speaker_id=speaker.id,
        start_time=0.0,
        end_time=5.0,
        duration=5.0,
        confidence=0.95,
        transcription="Hello world"
    )
    db_session.add(segment)
    db_session.commit()

    assert segment.id is not None
    assert segment.start_time == 0.0
    assert segment.end_time == 5.0
    assert segment.transcription == "Hello world"


@pytest.mark.unit
def test_conversation_insight(db_session):
    """Test conversation insight creation."""
    audio_file = AudioFile(filename="meeting.mp3", filepath="/meeting.mp3")
    db_session.add(audio_file)
    db_session.commit()

    insight = ConversationInsight(
        audio_file_id=audio_file.id,
        summary="Team discussed Q4 goals",
        sentiment_overall="positive",
        sentiment_score=0.8,
        key_topics=["Q4", "Goals", "Planning"],
        action_items=[{"item": "Prepare report", "assigned_to": "John"}]
    )
    db_session.add(insight)
    db_session.commit()

    assert insight.id is not None
    assert insight.summary == "Team discussed Q4 goals"
    assert len(insight.key_topics) == 3
    assert len(insight.action_items) == 1


@pytest.mark.unit
def test_speaker_insight(db_session):
    """Test speaker insight creation."""
    # Create dependencies
    speaker = Speaker(name="Speaker 1")
    audio_file = AudioFile(filename="test.mp3", filepath="/test.mp3")
    db_session.add_all([speaker, audio_file])
    db_session.commit()

    assoc = SpeakerAudioFile(
        speaker_id=speaker.id,
        audio_file_id=audio_file.id,
        total_speech_duration=100.0,
        segment_count=10
    )
    db_session.add(assoc)
    db_session.commit()

    # Create insight
    insight = SpeakerInsight(
        speaker_audio_file_id=assoc.id,
        speaking_style="Professional",
        sentiment="positive",
        sentiment_score=0.85,
        improvements=["Speak slower", "Use fewer filler words"],
        word_count=500,
        filler_words_count=12,
        speaking_pace=150.0
    )
    db_session.add(insight)
    db_session.commit()

    assert insight.id is not None
    assert insight.speaking_style == "Professional"
    assert len(insight.improvements) == 2
    assert insight.speaking_pace == 150.0


@pytest.mark.unit
def test_processing_job(db_session):
    """Test processing job creation."""
    audio_file = AudioFile(filename="test.mp3", filepath="/test.mp3")
    db_session.add(audio_file)
    db_session.commit()

    job = ProcessingJob(
        audio_file_id=audio_file.id,
        status=ProcessingStatus.QUEUED,
        progress=0,
        current_step="initialization"
    )
    db_session.add(job)
    db_session.commit()

    assert job.id is not None
    assert job.status == ProcessingStatus.QUEUED
    assert job.progress == 0


@pytest.mark.unit
def test_speaker_update_stats(db_session):
    """Test updating speaker statistics."""
    speaker = Speaker(
        name="Test Speaker",
        total_duration_seconds=100.0,
        file_count=2
    )
    db_session.add(speaker)
    db_session.commit()

    # Update stats
    speaker.total_duration_seconds += 50.0
    speaker.file_count += 1
    db_session.commit()

    db_session.refresh(speaker)
    assert speaker.total_duration_seconds == 150.0
    assert speaker.file_count == 3


@pytest.mark.unit
def test_query_speaker_files(db_session):
    """Test querying all files for a speaker."""
    speaker = Speaker(name="Speaker 1")
    db_session.add(speaker)
    db_session.commit()

    # Add multiple files
    for i in range(3):
        audio_file = AudioFile(
            filename=f"file_{i}.mp3",
            filepath=f"/path/to/file_{i}.mp3"
        )
        db_session.add(audio_file)
        db_session.flush()

        assoc = SpeakerAudioFile(
            speaker_id=speaker.id,
            audio_file_id=audio_file.id,
            total_speech_duration=100.0 + i * 10,
            segment_count=10 + i
        )
        db_session.add(assoc)

    db_session.commit()

    # Query associations
    associations = db_session.query(SpeakerAudioFile).filter(
        SpeakerAudioFile.speaker_id == speaker.id
    ).all()

    assert len(associations) == 3
    assert associations[0].total_speech_duration == 100.0
    assert associations[1].total_speech_duration == 110.0
    assert associations[2].total_speech_duration == 120.0
