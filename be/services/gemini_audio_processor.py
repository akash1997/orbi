"""Gemini-based audio processing service for complete audio pipeline.

This service uses Google's Gemini multimodal API to perform:
- Speaker diarization
- Speech transcription
- Speaker identification
- Insights generation

All through a single Gemini API call, replacing the traditional
pyannote + Whisper pipeline.
"""
import logging
import json
from pathlib import Path
from typing import Dict, Any, List, Tuple
import numpy as np
import google.generativeai as genai
from config import settings

logger = logging.getLogger(__name__)


class GeminiAudioProcessor:
    """Process audio entirely through Gemini API."""

    def __init__(self):
        """Initialize Gemini audio processor."""
        if not settings.GEMINI_API_KEY:
            raise ValueError("GEMINI_API_KEY is required for Gemini audio processor")

        genai.configure(api_key=settings.GEMINI_API_KEY)

        # Use configured Gemini model for audio analysis
        # Only Pro models support audio files
        model_name = settings.GEMINI_AUDIO_MODEL

        # Validate model supports audio
        # supported_audio_models = ['gemini-1.5-pro', 'gemini-1.5-pro-002', 'gemini-1.5-pro-latest']
        # if model_name not in supported_audio_models:
        #     logger.warning(
        #         f"Model '{model_name}' may not support audio files. "
        #         f"Supported models: {', '.join(supported_audio_models)}. "
        #         f"Falling back to gemini-1.5-pro"
        #     )
        #     model_name = 'gemini-1.5-pro'

        self.model = genai.GenerativeModel(model_name)
        logger.info(f"Initialized Gemini audio processor with {model_name}")

    def process_audio_file(
        self,
        audio_file_path: str | Path
    ) -> Dict[str, Any]:
        """
        Process audio file through Gemini API.

        Args:
            audio_file_path: Path to audio file

        Returns:
            Dictionary containing:
            - segments: List of speaker segments with timestamps and transcriptions
            - speakers: Dictionary of unique speakers
            - full_transcript: Complete formatted transcript
            - conversation_insights: Conversation-level insights
            - speaker_insights: Per-speaker insights
        """
        audio_file_path = Path(audio_file_path)

        if not audio_file_path.exists():
            raise FileNotFoundError(f"Audio file not found: {audio_file_path}")

        logger.info(f"Processing audio file with Gemini: {audio_file_path}")

        try:
            # Determine MIME type based on file extension
            mime_type = self._get_mime_type(audio_file_path)
            logger.info(f"Detected MIME type: {mime_type}")

            # Upload audio file to Gemini
            logger.info("Uploading audio file to Gemini...")
            audio_file = genai.upload_file(
                str(audio_file_path),
                mime_type=mime_type
            )
            logger.info(f"Uploaded file: {audio_file.name}")

            # Wait for file to be processed
            import time
            while audio_file.state.name == "PROCESSING":
                logger.info("Waiting for Gemini to process audio...")
                time.sleep(2)
                audio_file = genai.get_file(audio_file.name)

            if audio_file.state.name == "FAILED":
                raise RuntimeError(f"Gemini failed to process audio: {audio_file.state}")

            logger.info("Audio file ready for analysis")

            # Create comprehensive prompt for audio analysis
            prompt = self._build_comprehensive_prompt()

            # Generate analysis
            logger.info("Generating comprehensive audio analysis with Gemini...")
            # Using max allowed tokens for Gemini Pro (currently 100k input, ~8k output)
            # But in practice, 65k is more reliable for structured JSON output
            response = self.model.generate_content(
                [prompt, audio_file],
                generation_config={
                    "temperature": 0.2,
                    "max_output_tokens": 65536,  # Increased to handle longer responses
                },
                safety_settings=[
                    {
                        "category": "HARM_CATEGORY_HARASSMENT",
                        "threshold": "BLOCK_NONE",
                    },
                    {
                        "category": "HARM_CATEGORY_HATE_SPEECH",
                        "threshold": "BLOCK_NONE",
                    },
                    {
                        "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                        "threshold": "BLOCK_NONE",
                    },
                    {
                        "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                        "threshold": "BLOCK_NONE",
                    },
                ]
            )

            # Check if response was blocked
            if not response.candidates:
                raise ValueError(
                    "Gemini blocked the response. This may be due to safety filters. "
                    "The audio content may have triggered content policy restrictions."
                )

            # Check finish reason
            finish_reason = response.candidates[0].finish_reason
            if finish_reason != 1:  # 1 = STOP (successful completion)
                finish_reason_map = {
                    0: "FINISH_REASON_UNSPECIFIED",
                    1: "STOP",
                    2: "SAFETY",
                    3: "MAX_TOKENS",  # Response truncated due to token limit
                    4: "RECITATION",
                    5: "OTHER",
                    6: "BLOCKLIST",
                    7: "PROHIBITED_CONTENT",
                    8: "SPII",
                }
                reason_name = finish_reason_map.get(finish_reason, f"UNKNOWN({finish_reason})")

                logger.error(f"Gemini response incomplete. Finish reason: {reason_name}")

                if finish_reason == 2:  # SAFETY
                    raise ValueError(
                        f"Gemini blocked the response due to safety filters (finish_reason: {reason_name}). "
                        "The audio content may contain sensitive or policy-violating material. "
                        "Consider using the traditional pipeline for this file."
                    )
                elif finish_reason == 3:  # MAX_TOKENS
                    raise ValueError(
                        f"Gemini response truncated due to max_output_tokens limit (finish_reason: {reason_name}). "
                        "The audio file may be too long or complex for the Gemini pipeline. "
                        "Try using a shorter audio file or use the traditional pipeline."
                    )
                else:
                    raise ValueError(
                        f"Gemini response incomplete (finish_reason: {reason_name}). "
                        "Try processing this file again or use the traditional pipeline."
                    )

            # Extract content
            try:
                content = response.text
            except ValueError as e:
                # More detailed error if text accessor fails
                logger.error(f"Failed to access response.text: {e}")
                logger.error(f"Response candidates: {response.candidates}")
                raise ValueError(
                    f"Failed to extract text from Gemini response: {e}. "
                    "The response may have been filtered or incomplete."
                )

            logger.debug(f"Gemini response (first 500 chars): {content[:500]}")

            # Parse JSON response
            result = self._parse_gemini_response(content)

            # Clean up uploaded file
            try:
                genai.delete_file(audio_file.name)
                logger.info("Cleaned up uploaded file")
            except Exception as e:
                logger.warning(f"Failed to delete uploaded file: {e}")

            logger.info(f"Successfully processed audio with Gemini: "
                       f"{len(result['segments'])} segments, "
                       f"{len(result['speakers'])} speakers")

            return result

        except Exception as e:
            logger.error(f"Error processing audio with Gemini: {e}")
            raise

    def _get_mime_type(self, audio_file_path: Path) -> str:
        """
        Get MIME type for audio file based on extension.

        Args:
            audio_file_path: Path to audio file

        Returns:
            MIME type string
        """
        extension = audio_file_path.suffix.lower()

        mime_types = {
            '.mp3': 'audio/mpeg',
            '.wav': 'audio/wav',
            '.m4a': 'audio/mp4',
            '.flac': 'audio/flac',
            '.ogg': 'audio/ogg',
            '.aac': 'audio/aac',
            '.wma': 'audio/x-ms-wma',
            '.opus': 'audio/opus',
            '.webm': 'audio/webm'
        }

        mime_type = mime_types.get(extension)

        if not mime_type:
            # Default to generic audio type
            logger.warning(f"Unknown audio extension: {extension}, using audio/mpeg")
            mime_type = 'audio/mpeg'

        return mime_type

    def _build_comprehensive_prompt(self) -> str:
        """Build comprehensive prompt for Gemini audio analysis."""
        return """Analyze this audio file and provide a comprehensive analysis including speaker diarization, transcription, and insights.

Your analysis must be in valid JSON format with the following structure:

{
  "segments": [
    {
      "start": <float, start time in seconds>,
      "end": <float, end time in seconds>,
      "speaker_id": <string, unique identifier for the speaker, e.g., "SPEAKER_1", "SPEAKER_2">,
      "transcription": <string, what the speaker said>,
      "confidence": <float between 0 and 1, your confidence in this segment>
    }
  ],
  "speakers": {
    "SPEAKER_1": {
      "name": <string, actual name if mentioned in conversation, otherwise descriptive name like "Male Speaker 1">,
      "detected_name": <string or null, actual name if detected from conversation, e.g., "John", "Sarah">,
      "voice_characteristics": <string, description of voice qualities>,
      "total_speaking_time": <float, total seconds this speaker spoke>
    },
    "SPEAKER_2": {
      "name": <string, actual name if mentioned, otherwise descriptive name>,
      "detected_name": <string or null, actual name if detected>,
      "voice_characteristics": <string>,
      "total_speaking_time": <float>
    }
  },
  "full_transcript": <string, formatted transcript with speaker names>,
  "conversation_insights": {
    "summary": <string, 2-3 sentence overview of the conversation>,
    "sentiment_overall": <string, one of: "positive", "negative", "neutral", "mixed">,
    "sentiment_score": <float between -1.0 and 1.0>,
    "key_topics": [<list of strings, main topics discussed>],
    "action_items": [
      {
        "item": <string, task description>,
        "assigned_to": <string or null, person name if mentioned>,
        "mentioned_by": <string, speaker_id>,
        "priority": <string, one of: "high", "medium", "low">
      }
    ],
    "meetings_reminders": [
      {
        "type": <string, "meeting" or "reminder">,
        "description": <string, meeting/reminder details>,
        "date_time": <string or null, mentioned date/time>,
        "participants": [<list of strings, participant names>]
      }
    ]
  },
  "speaker_insights": {
    "SPEAKER_1": {
      "speaking_style": <string, description of speaking style>,
      "sentiment": <string, one of: "positive", "negative", "neutral">,
      "sentiment_score": <float between -1.0 and 1.0>,
      "word_count": <int, estimated word count>,
      "filler_words_count": <int, count of um, uh, like, etc.>,
      "speaking_pace": <float, words per minute>,
      "strengths": [<list of strings, communication strengths>],
      "improvements": [<list of strings, specific improvement suggestions>],
      "notable_patterns": [<list of strings, observed patterns>],
      "communication_effectiveness": <int, score from 1-10>
    }
  }
}

IMPORTANT INSTRUCTIONS:
1. Carefully listen to the entire audio
2. Identify distinct speakers by voice characteristics (pitch, tone, gender, accent)
3. Provide accurate timestamps for each segment (start and end in seconds)
4. Transcribe exactly what is said, including filler words
5. Maintain speaker consistency throughout - same voice should have same speaker_id
6. **NAME DETECTION**: Listen carefully for speaker names mentioned in the conversation:
   - If a speaker introduces themselves or is referred to by name, use that actual name
   - Set "detected_name" to the actual name (e.g., "John", "Sarah") if found
   - If no name is mentioned, set "detected_name" to null and use a descriptive name like "Male Speaker 1"
   - Use the detected name consistently in action items, meetings, and insights
7. Provide meaningful insights based on actual content
8. Respond ONLY with valid JSON - no markdown code blocks, no extra text
9. Calculate speaking metrics accurately (word count, pace, filler words)
10. Be specific and actionable in improvement suggestions

Begin your analysis now. Remember: ONLY output valid JSON, nothing else."""

    def _parse_gemini_response(self, content: str) -> Dict[str, Any]:
        """
        Parse Gemini's JSON response.

        Args:
            content: Raw response text from Gemini

        Returns:
            Parsed result dictionary
        """
        # Remove markdown code blocks if present
        content = content.strip()

        # Try different code block patterns
        if content.startswith("```json"):
            content = content[7:]  # Remove ```json
            if content.endswith("```"):
                content = content[:-3]  # Remove trailing ```
        elif content.startswith("```"):
            content = content[3:]  # Remove ```
            if content.endswith("```"):
                content = content[:-3]  # Remove trailing ```

        content = content.strip()

        # Try to parse JSON
        try:
            result = json.loads(content)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse Gemini response as JSON: {e}")
            logger.error(f"Response content (first 2000 chars): {content[:2000]}")
            logger.error(f"Response content (last 500 chars): {content[-500:]}")

            # Check if response appears truncated (unterminated string, missing closing brace, etc.)
            if "Unterminated string" in str(e) or not content.rstrip().endswith('}'):
                raise ValueError(
                    f"Gemini response appears truncated (likely hit max_output_tokens limit). "
                    f"JSON error: {e}\n"
                    f"The audio file may be too long for the Gemini pipeline. "
                    f"Try using the traditional pipeline for this audio file."
                )

            # Try to extract JSON from the content
            import re
            json_match = re.search(r'\{.*\}', content, re.DOTALL)
            if json_match:
                try:
                    result = json.loads(json_match.group(0))
                    logger.info("Successfully extracted JSON from response")
                except json.JSONDecodeError:
                    raise ValueError(
                        f"Gemini response is not valid JSON. Error: {e}\n"
                        f"Content preview: {content[:500]}..."
                    )
            else:
                raise ValueError(
                    f"Could not find JSON in Gemini response. Error: {e}\n"
                    f"Content preview: {content[:500]}..."
                )

        # Validate required fields
        required_fields = ['segments', 'speakers', 'full_transcript',
                          'conversation_insights', 'speaker_insights']

        missing_fields = [field for field in required_fields if field not in result]
        if missing_fields:
            logger.error(f"Missing required fields: {missing_fields}")
            logger.error(f"Available fields: {list(result.keys())}")
            raise ValueError(
                f"Missing required fields in Gemini response: {', '.join(missing_fields)}\n"
                f"Available fields: {', '.join(result.keys())}"
            )

        # Validate segments structure
        if not isinstance(result['segments'], list):
            raise ValueError(f"'segments' must be a list, got {type(result['segments'])}")

        if not result['segments']:
            logger.warning("Gemini returned empty segments list")
            raise ValueError("Gemini returned no audio segments. The audio may be too short or unclear.")

        for i, segment in enumerate(result['segments']):
            required_segment_fields = ['start', 'end', 'speaker_id', 'transcription']
            missing_segment_fields = [f for f in required_segment_fields if f not in segment]

            if missing_segment_fields:
                logger.error(f"Segment {i} missing fields: {missing_segment_fields}")
                logger.error(f"Segment {i} has fields: {list(segment.keys())}")
                raise ValueError(
                    f"Segment {i} missing required fields: {', '.join(missing_segment_fields)}"
                )

        # Add default confidence and calculate duration
        for segment in result['segments']:
            if 'confidence' not in segment:
                segment['confidence'] = 0.8

            # Calculate duration
            try:
                segment['duration'] = float(segment['end']) - float(segment['start'])
            except (ValueError, TypeError) as e:
                raise ValueError(
                    f"Invalid segment timestamps: start={segment.get('start')}, "
                    f"end={segment.get('end')}"
                )

        logger.info(f"Successfully validated Gemini response: "
                   f"{len(result['segments'])} segments, "
                   f"{len(result['speakers'])} speakers")
        return result

    def generate_speaker_embeddings(
        self,
        segments: List[Dict[str, Any]]
    ) -> Dict[str, np.ndarray]:
        """
        Generate synthetic embeddings for speakers based on Gemini analysis.

        Since Gemini doesn't provide voice embeddings, we generate synthetic ones
        based on speaker characteristics. These are used for consistency with the
        existing database schema.

        Args:
            segments: List of speaker segments

        Returns:
            Dictionary mapping speaker_id to synthetic embedding
        """
        embeddings = {}

        # Get unique speaker IDs
        speaker_ids = set(seg['speaker_id'] for seg in segments)

        # Generate deterministic but unique embeddings for each speaker
        for idx, speaker_id in enumerate(sorted(speaker_ids)):
            # Create a synthetic embedding (192 dimensions for pyannote compatibility)
            # Use speaker index to make it unique and reproducible
            np.random.seed(hash(speaker_id) % (2**32))
            embedding = np.random.randn(settings.EMBEDDING_DIMENSION)
            # Normalize
            embedding = embedding / np.linalg.norm(embedding)
            embeddings[speaker_id] = embedding

            logger.debug(f"Generated synthetic embedding for {speaker_id}")

        return embeddings

    def format_for_traditional_pipeline(
        self,
        gemini_result: Dict[str, Any]
    ) -> Tuple[List[Dict[str, Any]], Dict[str, np.ndarray], Dict[str, str]]:
        """
        Format Gemini results to match traditional pipeline output format.

        This allows the Gemini pipeline to integrate seamlessly with existing
        database storage and API response formats.

        Args:
            gemini_result: Raw Gemini processing result

        Returns:
            Tuple of (segments, embeddings, speaker_names)
        """
        # Extract segments
        segments = gemini_result['segments']

        # Generate synthetic embeddings
        embeddings = self.generate_speaker_embeddings(segments)

        # Extract speaker names
        speaker_names = {
            speaker_id: info['name']
            for speaker_id, info in gemini_result['speakers'].items()
        }

        return segments, embeddings, speaker_names
