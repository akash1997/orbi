"""Speech-to-text transcription service using Whisper."""
import logging
from pathlib import Path
from typing import List, Dict, Any
import whisper
import numpy as np
from config import settings
from services.audio_processor import AudioProcessor

logger = logging.getLogger(__name__)


class TranscriptionService:
    """Service for speech-to-text transcription using OpenAI Whisper."""

    def __init__(self):
        """Initialize transcription service."""
        try:
            self.model = whisper.load_model(settings.WHISPER_MODEL)
            logger.info(f"Loaded Whisper model: {settings.WHISPER_MODEL}")
        except Exception as e:
            logger.error(f"Error loading Whisper model: {e}")
            self.model = None

        self.audio_processor = AudioProcessor()

    def transcribe_file(
        self,
        audio_file_path: str | Path,
        language: str = None
    ) -> Dict[str, Any]:
        """
        Transcribe entire audio file.

        Args:
            audio_file_path: Path to audio file
            language: Language code (e.g., 'en', 'es') or None for auto-detect

        Returns:
            Dictionary with transcription results
        """
        if self.model is None:
            raise RuntimeError("Whisper model not loaded")

        try:
            audio_file_path = str(audio_file_path)

            # Transcribe
            result = self.model.transcribe(
                audio_file_path,
                language=language,
                task="transcribe",
                verbose=False
            )

            logger.info(f"Transcribed file: {audio_file_path}")
            return result

        except Exception as e:
            logger.error(f"Error transcribing file: {e}")
            raise

    def transcribe_segment(
        self,
        audio: np.ndarray,
        sample_rate: int,
        language: str = None
    ) -> str:
        """
        Transcribe audio segment.

        Args:
            audio: Audio array
            sample_rate: Sample rate
            language: Language code or None for auto-detect

        Returns:
            Transcribed text
        """
        if self.model is None:
            raise RuntimeError("Whisper model not loaded")

        try:
            # Whisper expects 16kHz audio
            if sample_rate != 16000:
                import librosa
                audio = librosa.resample(audio, orig_sr=sample_rate, target_sr=16000)

            # Transcribe
            result = self.model.transcribe(
                audio,
                language=language,
                task="transcribe",
                verbose=False
            )

            return result['text'].strip()

        except Exception as e:
            logger.error(f"Error transcribing segment: {e}")
            return ""

    def transcribe_segments(
        self,
        audio_file_path: str | Path,
        segments: List[Dict[str, Any]],
        language: str = None
    ) -> List[Dict[str, Any]]:
        """
        Transcribe multiple segments from an audio file.

        Args:
            audio_file_path: Path to audio file
            segments: List of segment dictionaries with 'start' and 'end' keys
            language: Language code or None for auto-detect

        Returns:
            List of segments with added 'transcription' field
        """
        if self.model is None:
            raise RuntimeError("Whisper model not loaded")

        try:
            # Load full audio
            audio, sr = self.audio_processor.process_audio_file(audio_file_path)[:2]

            transcribed_segments = []

            for segment in segments:
                try:
                    # Extract segment audio
                    segment_audio = self.audio_processor.extract_audio_segment(
                        audio,
                        sr,
                        segment['start'],
                        segment['end']
                    )

                    # Transcribe
                    transcription = self.transcribe_segment(segment_audio, sr, language)

                    # Add transcription to segment
                    segment_with_text = segment.copy()
                    segment_with_text['transcription'] = transcription

                    transcribed_segments.append(segment_with_text)

                    logger.debug(f"Transcribed segment [{segment['start']:.2f}-{segment['end']:.2f}]: "
                               f"{transcription[:50]}...")

                except Exception as e:
                    logger.warning(f"Failed to transcribe segment "
                                 f"[{segment['start']:.2f}-{segment['end']:.2f}]: {e}")
                    segment_with_text = segment.copy()
                    segment_with_text['transcription'] = ""
                    transcribed_segments.append(segment_with_text)

            logger.info(f"Transcribed {len(transcribed_segments)} segments")
            return transcribed_segments

        except Exception as e:
            logger.error(f"Error transcribing segments: {e}")
            raise

    def format_transcript(
        self,
        segments: List[Dict[str, Any]],
        include_timestamps: bool = False,
        speaker_names: Dict[str, str] = None
    ) -> str:
        """
        Format transcribed segments into readable transcript.

        Args:
            segments: List of segments with 'speaker_id' and 'transcription'
            include_timestamps: Whether to include timestamps
            speaker_names: Optional mapping of speaker IDs to names

        Returns:
            Formatted transcript string
        """
        lines = []

        for segment in segments:
            speaker_id = segment.get('speaker_id', 'Unknown')
            transcription = segment.get('transcription', '')

            if not transcription:
                continue

            # Get speaker name
            speaker_name = speaker_names.get(speaker_id, speaker_id) if speaker_names else speaker_id

            # Format line
            if include_timestamps:
                timestamp = f"[{segment['start']:.1f}s - {segment['end']:.1f}s]"
                line = f"{timestamp} {speaker_name}: {transcription}"
            else:
                line = f"{speaker_name}: {transcription}"

            lines.append(line)

        return "\n".join(lines)

    def get_transcript_by_speaker(
        self,
        segments: List[Dict[str, Any]]
    ) -> Dict[str, str]:
        """
        Get concatenated transcript for each speaker.

        Args:
            segments: List of segments with 'speaker_id' and 'transcription'

        Returns:
            Dictionary mapping speaker_id to their full transcript
        """
        speaker_transcripts = {}

        for segment in segments:
            speaker_id = segment.get('speaker_id')
            transcription = segment.get('transcription', '').strip()

            if speaker_id and transcription:
                if speaker_id not in speaker_transcripts:
                    speaker_transcripts[speaker_id] = []
                speaker_transcripts[speaker_id].append(transcription)

        # Join all transcripts for each speaker
        return {
            speaker_id: " ".join(transcripts)
            for speaker_id, transcripts in speaker_transcripts.items()
        }
