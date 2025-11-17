"""Speaker management service for CRUD operations and identification."""
import logging
from typing import List, Dict, Any, Optional, Tuple
from sqlalchemy.orm import Session
from datetime import datetime
import numpy as np

from database.models import (
    Speaker,
    AudioFile,
    SpeakerAudioFile,
    SpeakerSegment
)
from database.vector_store import VectorStore
from config import settings

logger = logging.getLogger(__name__)


class SpeakerManager:
    """Service for managing speakers and identification."""

    def __init__(self, db: Session, vector_store: VectorStore = None):
        """
        Initialize speaker manager.

        Args:
            db: Database session
            vector_store: Vector store instance
        """
        self.db = db
        self.vector_store = vector_store or VectorStore()

    def identify_or_create_speaker(
        self,
        embedding: np.ndarray,
        audio_file_id: str,
        segment_id: str
    ) -> Tuple[str, bool]:
        """
        Identify speaker from embedding or create new speaker.

        Args:
            embedding: Speaker embedding
            audio_file_id: Audio file ID
            segment_id: Segment ID

        Returns:
            Tuple of (speaker_id, is_new)
        """
        # Search for matching speaker
        match = self.vector_store.find_matching_speaker(
            embedding,
            similarity_threshold=settings.SPEAKER_SIMILARITY_THRESHOLD
        )

        if match:
            speaker_id, similarity = match
            logger.info(f"Matched to existing speaker {speaker_id} with similarity {similarity:.3f}")

            # Add embedding to vector store
            self.vector_store.add_embedding(embedding, speaker_id, segment_id, audio_file_id)
            self.vector_store.save()

            return speaker_id, False

        else:
            # Create new speaker
            speaker = self.create_speaker()
            speaker_id = speaker.id

            # Add embedding to vector store
            self.vector_store.add_embedding(embedding, speaker_id, segment_id, audio_file_id)
            self.vector_store.save()

            logger.info(f"Created new speaker {speaker_id}")
            return speaker_id, True

    def create_speaker(self, name: str = None) -> Speaker:
        """
        Create a new speaker.

        Args:
            name: Speaker name (optional)

        Returns:
            Created speaker
        """
        # Generate default name if not provided
        if not name:
            count = self.db.query(Speaker).count()
            name = f"Speaker_{count + 1:03d}"

        speaker = Speaker(name=name)
        self.db.add(speaker)
        self.db.commit()
        self.db.refresh(speaker)

        logger.info(f"Created speaker: {speaker.id} - {speaker.name}")
        return speaker

    def get_speaker(self, speaker_id: str) -> Optional[Speaker]:
        """
        Get speaker by ID.

        Args:
            speaker_id: Speaker ID

        Returns:
            Speaker or None if not found
        """
        return self.db.query(Speaker).filter(Speaker.id == speaker_id).first()

    def list_speakers(
        self,
        limit: int = 100,
        offset: int = 0
    ) -> List[Speaker]:
        """
        List all speakers.

        Args:
            limit: Maximum number of speakers to return
            offset: Offset for pagination

        Returns:
            List of speakers
        """
        return self.db.query(Speaker).offset(offset).limit(limit).all()

    def update_speaker(
        self,
        speaker_id: str,
        name: str = None,
        metadata: Dict = None
    ) -> Optional[Speaker]:
        """
        Update speaker information.

        Args:
            speaker_id: Speaker ID
            name: New name (optional)
            metadata: New metadata (optional)

        Returns:
            Updated speaker or None if not found
        """
        speaker = self.get_speaker(speaker_id)
        if not speaker:
            return None

        if name:
            speaker.name = name
        if metadata:
            speaker.extra_metadata = metadata

        speaker.updated_at = datetime.utcnow()
        self.db.commit()
        self.db.refresh(speaker)

        logger.info(f"Updated speaker: {speaker_id}")
        return speaker

    def update_speaker_stats(
        self,
        speaker_id: str,
        audio_file_id: str,
        duration: float
    ):
        """
        Update speaker statistics after processing.

        Args:
            speaker_id: Speaker ID
            audio_file_id: Audio file ID
            duration: Duration of speech in this file
        """
        speaker = self.get_speaker(speaker_id)
        if not speaker:
            logger.warning(f"Speaker {speaker_id} not found for stats update")
            return

        # Update total duration
        speaker.total_duration_seconds += duration

        # Check if this is a new file for this speaker
        existing = self.db.query(SpeakerAudioFile).filter(
            SpeakerAudioFile.speaker_id == speaker_id,
            SpeakerAudioFile.audio_file_id == audio_file_id
        ).first()

        if not existing:
            speaker.file_count += 1

        speaker.updated_at = datetime.utcnow()
        self.db.commit()

        logger.debug(f"Updated stats for speaker {speaker_id}")

    def create_speaker_audio_association(
        self,
        speaker_id: str,
        audio_file_id: str,
        total_duration: float,
        segment_count: int
    ) -> SpeakerAudioFile:
        """
        Create association between speaker and audio file.

        Args:
            speaker_id: Speaker ID
            audio_file_id: Audio file ID
            total_duration: Total speech duration
            segment_count: Number of segments

        Returns:
            Created association
        """
        association = SpeakerAudioFile(
            speaker_id=speaker_id,
            audio_file_id=audio_file_id,
            total_speech_duration=total_duration,
            segment_count=segment_count
        )
        self.db.add(association)
        self.db.commit()
        self.db.refresh(association)

        return association

    def get_speaker_files(self, speaker_id: str) -> List[Dict[str, Any]]:
        """
        Get all audio files where speaker appears.

        Args:
            speaker_id: Speaker ID

        Returns:
            List of file information dictionaries
        """
        associations = self.db.query(SpeakerAudioFile).filter(
            SpeakerAudioFile.speaker_id == speaker_id
        ).all()

        files = []
        for assoc in associations:
            audio_file = self.db.query(AudioFile).filter(
                AudioFile.id == assoc.audio_file_id
            ).first()

            if audio_file:
                files.append({
                    "audio_file_id": audio_file.id,
                    "filename": audio_file.filename,
                    "duration_in_file": assoc.total_speech_duration,
                    "segment_count": assoc.segment_count,
                    "uploaded_at": audio_file.uploaded_at.isoformat()
                })

        return files

    def merge_speakers(
        self,
        source_speaker_id: str,
        target_speaker_id: str
    ) -> bool:
        """
        Merge two speakers (source into target).

        Args:
            source_speaker_id: Source speaker ID (will be deleted)
            target_speaker_id: Target speaker ID (will be kept)

        Returns:
            True if successful, False otherwise
        """
        source = self.get_speaker(source_speaker_id)
        target = self.get_speaker(target_speaker_id)

        if not source or not target:
            logger.error("Source or target speaker not found")
            return False

        try:
            # Update all segments
            self.db.query(SpeakerSegment).filter(
                SpeakerSegment.speaker_id == source_speaker_id
            ).update({"speaker_id": target_speaker_id})

            # Update all associations
            source_assocs = self.db.query(SpeakerAudioFile).filter(
                SpeakerAudioFile.speaker_id == source_speaker_id
            ).all()

            for assoc in source_assocs:
                # Check if target already has association with this file
                existing = self.db.query(SpeakerAudioFile).filter(
                    SpeakerAudioFile.speaker_id == target_speaker_id,
                    SpeakerAudioFile.audio_file_id == assoc.audio_file_id
                ).first()

                if existing:
                    # Merge durations
                    existing.total_speech_duration += assoc.total_speech_duration
                    existing.segment_count += assoc.segment_count
                    self.db.delete(assoc)
                else:
                    # Transfer association
                    assoc.speaker_id = target_speaker_id

            # Update target stats
            target.total_duration_seconds += source.total_duration_seconds
            target.file_count = self.db.query(SpeakerAudioFile).filter(
                SpeakerAudioFile.speaker_id == target_speaker_id
            ).count()

            # Delete source speaker
            self.db.delete(source)

            # Update vector store (mark source embeddings for rebuild)
            self.vector_store.remove_speaker(source_speaker_id)
            self.vector_store.save()

            self.db.commit()

            logger.info(f"Merged speaker {source_speaker_id} into {target_speaker_id}")
            return True

        except Exception as e:
            logger.error(f"Error merging speakers: {e}")
            self.db.rollback()
            return False

    def delete_speaker(self, speaker_id: str) -> bool:
        """
        Delete a speaker and all associated data.

        Args:
            speaker_id: Speaker ID

        Returns:
            True if successful, False otherwise
        """
        speaker = self.get_speaker(speaker_id)
        if not speaker:
            return False

        try:
            # Delete associations
            self.db.query(SpeakerAudioFile).filter(
                SpeakerAudioFile.speaker_id == speaker_id
            ).delete()

            # Delete segments
            self.db.query(SpeakerSegment).filter(
                SpeakerSegment.speaker_id == speaker_id
            ).delete()

            # Delete speaker
            self.db.delete(speaker)

            # Remove from vector store
            self.vector_store.remove_speaker(speaker_id)
            self.vector_store.save()

            self.db.commit()

            logger.info(f"Deleted speaker {speaker_id}")
            return True

        except Exception as e:
            logger.error(f"Error deleting speaker: {e}")
            self.db.rollback()
            return False
