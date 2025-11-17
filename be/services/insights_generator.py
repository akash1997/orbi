"""Service for generating conversation and speaker insights using LLM."""
import logging
from typing import Dict, List, Any
from sqlalchemy.orm import Session

from database.models import ConversationInsight, SpeakerInsight, SpeakerAudioFile
from utils.llm_client import (
    LLMClient,
    extract_word_count,
    count_filler_words,
    calculate_speaking_pace
)

logger = logging.getLogger(__name__)


class InsightsGenerator:
    """Service for generating AI-powered insights from conversations."""

    def __init__(self, db: Session):
        """
        Initialize insights generator.

        Args:
            db: Database session
        """
        self.db = db
        try:
            self.llm_client = LLMClient()
        except Exception as e:
            logger.error(f"Error initializing LLM client: {e}")
            self.llm_client = None

    def generate_conversation_insights(
        self,
        audio_file_id: str,
        full_transcript: str,
        speaker_names: Dict[str, str] = None
    ) -> ConversationInsight:
        """
        Generate conversation-level insights.

        Args:
            audio_file_id: Audio file ID
            full_transcript: Full conversation transcript
            speaker_names: Optional mapping of speaker IDs to names

        Returns:
            Created ConversationInsight
        """
        if not self.llm_client:
            logger.error("LLM client not available")
            raise RuntimeError("LLM client not initialized")

        try:
            # Generate insights using LLM
            insights_data = self.llm_client.generate_conversation_insights(
                full_transcript,
                speaker_names
            )

            # Create database record
            insight = ConversationInsight(
                audio_file_id=audio_file_id,
                summary=insights_data.get('summary'),
                sentiment_overall=insights_data.get('sentiment_overall'),
                sentiment_score=insights_data.get('sentiment_score'),
                key_topics=insights_data.get('key_topics', []),
                action_items=insights_data.get('action_items', []),
                meetings_reminders=insights_data.get('meetings_reminders', [])
            )

            self.db.add(insight)
            self.db.commit()
            self.db.refresh(insight)

            logger.info(f"Generated conversation insights for audio {audio_file_id}")
            return insight

        except Exception as e:
            logger.error(f"Error generating conversation insights: {e}")
            self.db.rollback()
            raise

    def generate_speaker_insights(
        self,
        speaker_audio_file_id: str,
        speaker_transcript: str,
        speaker_name: str,
        total_duration: float
    ) -> SpeakerInsight:
        """
        Generate speaker-specific insights.

        Args:
            speaker_audio_file_id: SpeakerAudioFile ID
            speaker_transcript: Speaker's full transcript
            speaker_name: Speaker name
            total_duration: Total speaking duration in seconds

        Returns:
            Created SpeakerInsight
        """
        if not self.llm_client:
            logger.error("LLM client not available")
            raise RuntimeError("LLM client not initialized")

        try:
            # Calculate metrics
            word_count = extract_word_count(speaker_transcript)
            filler_count = count_filler_words(speaker_transcript)
            speaking_pace = calculate_speaking_pace(speaker_transcript, total_duration)

            # Generate LLM insights
            llm_insights = self.llm_client.generate_speaker_insights(
                speaker_transcript,
                speaker_name
            )

            # Create database record
            insight = SpeakerInsight(
                speaker_audio_file_id=speaker_audio_file_id,
                speaking_style=llm_insights.get('speaking_style'),
                sentiment=llm_insights.get('sentiment'),
                sentiment_score=llm_insights.get('sentiment_score'),
                improvements=llm_insights.get('improvements', []),
                word_count=word_count,
                filler_words_count=filler_count,
                speaking_pace=speaking_pace
            )

            self.db.add(insight)
            self.db.commit()
            self.db.refresh(insight)

            logger.info(f"Generated speaker insights for {speaker_name}")
            return insight

        except Exception as e:
            logger.error(f"Error generating speaker insights: {e}")
            self.db.rollback()
            raise

    def generate_all_speaker_insights(
        self,
        audio_file_id: str,
        speaker_transcripts: Dict[str, str],
        speaker_durations: Dict[str, float],
        speaker_names: Dict[str, str] = None
    ) -> List[SpeakerInsight]:
        """
        Generate insights for all speakers in a conversation.

        Args:
            audio_file_id: Audio file ID
            speaker_transcripts: Dictionary mapping speaker_id to transcript
            speaker_durations: Dictionary mapping speaker_id to duration
            speaker_names: Optional mapping of speaker IDs to names

        Returns:
            List of created SpeakerInsights
        """
        insights = []

        for speaker_id, transcript in speaker_transcripts.items():
            if not transcript.strip():
                continue

            try:
                # Get speaker-audio association
                association = self.db.query(SpeakerAudioFile).filter(
                    SpeakerAudioFile.speaker_id == speaker_id,
                    SpeakerAudioFile.audio_file_id == audio_file_id
                ).first()

                if not association:
                    logger.warning(f"No association found for speaker {speaker_id} in audio {audio_file_id}")
                    continue

                # Get speaker name
                speaker_name = speaker_names.get(speaker_id, speaker_id) if speaker_names else speaker_id

                # Get duration
                duration = speaker_durations.get(speaker_id, association.total_speech_duration)

                # Generate insights
                insight = self.generate_speaker_insights(
                    association.id,
                    transcript,
                    speaker_name,
                    duration
                )

                insights.append(insight)

            except Exception as e:
                logger.error(f"Error generating insights for speaker {speaker_id}: {e}")
                continue

        logger.info(f"Generated insights for {len(insights)} speakers")
        return insights

    def get_conversation_insights(self, audio_file_id: str) -> ConversationInsight:
        """
        Get conversation insights for an audio file.

        Args:
            audio_file_id: Audio file ID

        Returns:
            ConversationInsight or None
        """
        return self.db.query(ConversationInsight).filter(
            ConversationInsight.audio_file_id == audio_file_id
        ).first()

    def get_speaker_insights(self, speaker_audio_file_id: str) -> SpeakerInsight:
        """
        Get speaker insights for a speaker-audio association.

        Args:
            speaker_audio_file_id: SpeakerAudioFile ID

        Returns:
            SpeakerInsight or None
        """
        return self.db.query(SpeakerInsight).filter(
            SpeakerInsight.speaker_audio_file_id == speaker_audio_file_id
        ).first()
