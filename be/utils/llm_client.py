"""LLM client for conversation insights generation."""
import json
import logging
from typing import Dict, Any, Optional
from config import settings

logger = logging.getLogger(__name__)


class LLMClient:
    """Client for interacting with LLM APIs (OpenAI or Anthropic)."""

    def __init__(self, provider: str = None, model: str = None):
        """
        Initialize LLM client.

        Args:
            provider: LLM provider ("openai" or "anthropic")
            model: Model name
        """
        self.provider = provider or settings.LLM_PROVIDER
        self.model = model or settings.LLM_MODEL

        if self.provider == "openai":
            from openai import OpenAI
            self.client = OpenAI(api_key=settings.OPENAI_API_KEY)
        elif self.provider == "anthropic":
            from anthropic import Anthropic
            self.client = Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        else:
            raise ValueError(f"Unsupported LLM provider: {self.provider}")

        logger.info(f"Initialized LLM client: {self.provider} - {self.model}")

    def generate_conversation_insights(
        self,
        transcript: str,
        speaker_labels: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """
        Generate conversation insights from transcript.

        Args:
            transcript: Full conversation transcript
            speaker_labels: Optional mapping of speaker IDs to names

        Returns:
            Dictionary containing insights
        """
        prompt = self._build_conversation_prompt(transcript, speaker_labels)

        try:
            if self.provider == "openai":
                response = self.client.chat.completions.create(
                    model=self.model,
                    messages=[
                        {"role": "system", "content": "You are an expert conversation analyst. Analyze conversations and provide structured insights in JSON format."},
                        {"role": "user", "content": prompt}
                    ],
                    temperature=0.3,
                    response_format={"type": "json_object"}
                )
                content = response.choices[0].message.content
            elif self.provider == "anthropic":
                response = self.client.messages.create(
                    model=self.model,
                    max_tokens=4096,
                    temperature=0.3,
                    messages=[
                        {"role": "user", "content": prompt}
                    ]
                )
                content = response.content[0].text
            else:
                raise ValueError(f"Unsupported provider: {self.provider}")

            # Parse JSON response
            insights = json.loads(content)
            logger.info("Successfully generated conversation insights")
            return insights

        except Exception as e:
            logger.error(f"Error generating conversation insights: {e}")
            raise

    def generate_speaker_insights(
        self,
        speaker_transcript: str,
        speaker_name: str = "Speaker"
    ) -> Dict[str, Any]:
        """
        Generate insights for a specific speaker.

        Args:
            speaker_transcript: Transcript of speaker's utterances
            speaker_name: Speaker name or identifier

        Returns:
            Dictionary containing speaker insights
        """
        prompt = self._build_speaker_prompt(speaker_transcript, speaker_name)

        try:
            if self.provider == "openai":
                response = self.client.chat.completions.create(
                    model=self.model,
                    messages=[
                        {"role": "system", "content": "You are an expert speech coach analyzing individual speaking patterns. Provide constructive feedback in JSON format."},
                        {"role": "user", "content": prompt}
                    ],
                    temperature=0.3,
                    response_format={"type": "json_object"}
                )
                content = response.choices[0].message.content
            elif self.provider == "anthropic":
                response = self.client.messages.create(
                    model=self.model,
                    max_tokens=2048,
                    temperature=0.3,
                    messages=[
                        {"role": "user", "content": prompt}
                    ]
                )
                content = response.content[0].text
            else:
                raise ValueError(f"Unsupported provider: {self.provider}")

            insights = json.loads(content)
            logger.info(f"Successfully generated insights for {speaker_name}")
            return insights

        except Exception as e:
            logger.error(f"Error generating speaker insights: {e}")
            raise

    def _build_conversation_prompt(
        self,
        transcript: str,
        speaker_labels: Optional[Dict[str, str]] = None
    ) -> str:
        """Build prompt for conversation analysis."""
        speaker_info = ""
        if speaker_labels:
            speaker_info = "\n\nSPEAKER LABELS:\n" + "\n".join(
                [f"- {sid}: {name}" for sid, name in speaker_labels.items()]
            )

        return f"""Analyze the following conversation transcript and provide a comprehensive analysis.

TRANSCRIPT:
{transcript}
{speaker_info}

Provide your analysis in the following JSON format:

{{
  "summary": "2-3 sentence overview of the conversation",
  "sentiment_overall": "positive/negative/neutral/mixed",
  "sentiment_score": <float between -1.0 and 1.0>,
  "key_topics": ["topic1", "topic2", "topic3"],
  "action_items": [
    {{
      "item": "task description",
      "assigned_to": "person name or null if not mentioned",
      "mentioned_by": "speaker_id",
      "priority": "high/medium/low"
    }}
  ],
  "meetings_reminders": [
    {{
      "type": "meeting or reminder",
      "description": "meeting/reminder details",
      "date_time": "mentioned date/time or null",
      "participants": ["person1", "person2"]
    }}
  ]
}}

Focus on extracting actionable information and providing meaningful insights."""

    def _build_speaker_prompt(
        self,
        speaker_transcript: str,
        speaker_name: str
    ) -> str:
        """Build prompt for speaker-specific analysis."""
        return f"""Analyze the speaking style and provide feedback for {speaker_name}.

SPEAKER TRANSCRIPT:
{speaker_transcript}

Provide your analysis in the following JSON format:

{{
  "speaking_style": "brief description of speaking style (e.g., formal, casual, technical, enthusiastic)",
  "sentiment": "positive/negative/neutral",
  "sentiment_score": <float between -1.0 and 1.0>,
  "strengths": ["strength1", "strength2", "strength3"],
  "improvements": [
    "specific improvement suggestion 1",
    "specific improvement suggestion 2",
    "specific improvement suggestion 3"
  ],
  "notable_patterns": ["pattern1", "pattern2"],
  "communication_effectiveness": <score from 1-10>
}}

Provide constructive, actionable feedback that will help improve communication skills."""


def extract_word_count(transcript: str) -> int:
    """
    Extract word count from transcript.

    Args:
        transcript: Text transcript

    Returns:
        Word count
    """
    return len(transcript.split())


def count_filler_words(transcript: str) -> int:
    """
    Count filler words in transcript.

    Args:
        transcript: Text transcript

    Returns:
        Filler word count
    """
    filler_words = [
        "um", "uh", "like", "you know", "sort of", "kind of",
        "i mean", "basically", "actually", "literally"
    ]

    transcript_lower = transcript.lower()
    count = sum(transcript_lower.count(filler) for filler in filler_words)
    return count


def calculate_speaking_pace(transcript: str, duration_seconds: float) -> float:
    """
    Calculate speaking pace in words per minute.

    Args:
        transcript: Text transcript
        duration_seconds: Duration in seconds

    Returns:
        Words per minute
    """
    word_count = extract_word_count(transcript)
    if duration_seconds > 0:
        return (word_count / duration_seconds) * 60
    return 0.0
