"""SQLAlchemy database models."""
from sqlalchemy import Column, String, Float, Integer, Boolean, Text, DateTime, ForeignKey, Enum, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
import enum


Base = declarative_base()


def generate_uuid():
    """Generate a UUID string."""
    return str(uuid.uuid4())


class ProcessingStatus(str, enum.Enum):
    """Processing status enum."""
    QUEUED = "queued"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class Speaker(Base):
    """Speaker model - represents a unique speaker across all recordings."""
    __tablename__ = "speakers"

    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String, nullable=True)  # User can assign name, default "Speaker_001"
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    total_duration_seconds = Column(Float, default=0.0)  # Total speech time across all files
    file_count = Column(Integer, default=0)  # Number of files speaker appears in
    average_sentiment = Column(Float, nullable=True)  # Average sentiment score
    extra_metadata = Column(JSON, nullable=True)  # Extensible metadata

    # Relationships
    audio_files = relationship("SpeakerAudioFile", back_populates="speaker")
    segments = relationship("SpeakerSegment", back_populates="speaker")

    def __repr__(self):
        return f"<Speaker(id={self.id}, name={self.name})>"


class AudioFile(Base):
    """Audio file model - represents an uploaded audio file."""
    __tablename__ = "audio_files"

    id = Column(String, primary_key=True, default=generate_uuid)
    filename = Column(String, nullable=False)
    filepath = Column(String, nullable=False)
    duration = Column(Float, nullable=True)  # Duration in seconds
    format = Column(String, nullable=True)  # File format (mp3, wav, etc.)
    uploaded_at = Column(DateTime, default=datetime.utcnow)
    processing_status = Column(Enum(ProcessingStatus), default=ProcessingStatus.QUEUED)
    processed_at = Column(DateTime, nullable=True)
    error_message = Column(Text, nullable=True)

    # Relationships
    speakers = relationship("SpeakerAudioFile", back_populates="audio_file")
    segments = relationship("SpeakerSegment", back_populates="audio_file")
    conversation_insight = relationship("ConversationInsight", back_populates="audio_file", uselist=False)
    processing_job = relationship("ProcessingJob", back_populates="audio_file", uselist=False)

    def __repr__(self):
        return f"<AudioFile(id={self.id}, filename={self.filename}, status={self.processing_status})>"


class SpeakerAudioFile(Base):
    """Association table between speakers and audio files with metadata."""
    __tablename__ = "speaker_audio_files"

    id = Column(String, primary_key=True, default=generate_uuid)
    speaker_id = Column(String, ForeignKey("speakers.id"), nullable=False)
    audio_file_id = Column(String, ForeignKey("audio_files.id"), nullable=False)
    total_speech_duration = Column(Float, nullable=False)  # Speaker's total time in this file
    segment_count = Column(Integer, default=0)  # Number of segments for this speaker in this file
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    speaker = relationship("Speaker", back_populates="audio_files")
    audio_file = relationship("AudioFile", back_populates="speakers")
    speaker_insight = relationship("SpeakerInsight", back_populates="speaker_audio_file", uselist=False)

    def __repr__(self):
        return f"<SpeakerAudioFile(speaker_id={self.speaker_id}, audio_file_id={self.audio_file_id})>"


class SpeakerSegment(Base):
    """Speaker segment model - represents a time segment where a speaker is talking."""
    __tablename__ = "speaker_segments"

    id = Column(String, primary_key=True, default=generate_uuid)
    audio_file_id = Column(String, ForeignKey("audio_files.id"), nullable=False)
    speaker_id = Column(String, ForeignKey("speakers.id"), nullable=False)
    start_time = Column(Float, nullable=False)  # Start time in seconds
    end_time = Column(Float, nullable=False)  # End time in seconds
    duration = Column(Float, nullable=False)  # Segment duration
    confidence = Column(Float, nullable=True)  # Diarization confidence
    transcription = Column(Text, nullable=True)  # Transcribed text for this segment
    embedding_id = Column(String, nullable=True)  # Reference to embedding in vector store

    # Relationships
    audio_file = relationship("AudioFile", back_populates="segments")
    speaker = relationship("Speaker", back_populates="segments")

    def __repr__(self):
        return f"<SpeakerSegment(id={self.id}, speaker_id={self.speaker_id}, start={self.start_time}, end={self.end_time})>"


class ConversationInsight(Base):
    """Conversation-level insights generated by LLM."""
    __tablename__ = "conversation_insights"

    id = Column(String, primary_key=True, default=generate_uuid)
    audio_file_id = Column(String, ForeignKey("audio_files.id"), nullable=False)
    summary = Column(Text, nullable=True)  # Conversation summary
    sentiment_overall = Column(String, nullable=True)  # positive/negative/neutral/mixed
    sentiment_score = Column(Float, nullable=True)  # -1 to 1
    key_topics = Column(JSON, nullable=True)  # Array of topics
    action_items = Column(JSON, nullable=True)  # Array of action items
    meetings_reminders = Column(JSON, nullable=True)  # Array of meetings/reminders
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    audio_file = relationship("AudioFile", back_populates="conversation_insight")

    def __repr__(self):
        return f"<ConversationInsight(id={self.id}, audio_file_id={self.audio_file_id})>"


class SpeakerInsight(Base):
    """Speaker-specific insights for a particular audio file."""
    __tablename__ = "speaker_insights"

    id = Column(String, primary_key=True, default=generate_uuid)
    speaker_audio_file_id = Column(String, ForeignKey("speaker_audio_files.id"), nullable=False)
    speaking_style = Column(Text, nullable=True)  # Description of speaking style
    sentiment = Column(String, nullable=True)  # Speaker's sentiment
    sentiment_score = Column(Float, nullable=True)  # -1 to 1
    improvements = Column(JSON, nullable=True)  # Array of improvement suggestions
    word_count = Column(Integer, nullable=True)
    filler_words_count = Column(Integer, nullable=True)
    speaking_pace = Column(Float, nullable=True)  # Words per minute
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    speaker_audio_file = relationship("SpeakerAudioFile", back_populates="speaker_insight")

    def __repr__(self):
        return f"<SpeakerInsight(id={self.id}, speaker_audio_file_id={self.speaker_audio_file_id})>"


class ProcessingJob(Base):
    """Processing job model - tracks async processing status."""
    __tablename__ = "processing_jobs"

    id = Column(String, primary_key=True, default=generate_uuid)
    audio_file_id = Column(String, ForeignKey("audio_files.id"), nullable=False)
    celery_task_id = Column(String, nullable=True)  # Celery task ID for tracking
    status = Column(Enum(ProcessingStatus), default=ProcessingStatus.QUEUED)
    progress = Column(Integer, default=0)  # 0-100%
    current_step = Column(String, nullable=True)  # e.g., "diarization", "transcription", "insights"
    created_at = Column(DateTime, default=datetime.utcnow)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    error_message = Column(Text, nullable=True)
    result = Column(JSON, nullable=True)  # Summary of processing results

    # Relationships
    audio_file = relationship("AudioFile", back_populates="processing_job")

    def __repr__(self):
        return f"<ProcessingJob(id={self.id}, status={self.status}, progress={self.progress}%)>"
