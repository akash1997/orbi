"""Audio preprocessing service."""
import logging
from pathlib import Path
import numpy as np
from typing import Tuple
from utils.audio_utils import load_audio, get_audio_duration, normalize_audio
from config import settings

logger = logging.getLogger(__name__)


class AudioProcessor:
    """Service for audio preprocessing and validation."""

    def __init__(self):
        """Initialize audio processor."""
        self.target_sr = 16000  # 16kHz for speech models

    def process_audio_file(self, file_path: str | Path) -> Tuple[np.ndarray, int, float]:
        """
        Process audio file for speaker analysis.

        Args:
            file_path: Path to audio file

        Returns:
            Tuple of (audio_array, sample_rate, duration)
        """
        try:
            # Get duration first
            duration = get_audio_duration(file_path)

            # Validate duration
            if duration > settings.MAX_AUDIO_DURATION:
                raise ValueError(
                    f"Audio duration ({duration:.1f}s) exceeds maximum "
                    f"allowed duration ({settings.MAX_AUDIO_DURATION}s)"
                )

            # Load and resample audio
            audio, sr = load_audio(file_path, target_sr=self.target_sr)

            # Normalize audio
            audio = normalize_audio(audio)

            logger.info(f"Processed audio file: {file_path}, duration: {duration:.2f}s")
            return audio, sr, duration

        except Exception as e:
            logger.error(f"Error processing audio file {file_path}: {e}")
            raise

    def validate_audio_file(self, file_path: str | Path) -> bool:
        """
        Validate audio file format and properties.

        Args:
            file_path: Path to audio file

        Returns:
            True if valid, raises exception otherwise
        """
        file_path = Path(file_path)

        # Check if file exists
        if not file_path.exists():
            raise FileNotFoundError(f"Audio file not found: {file_path}")

        # Check file extension
        if file_path.suffix.lower() not in settings.ALLOWED_EXTENSIONS:
            raise ValueError(
                f"Invalid audio format: {file_path.suffix}. "
                f"Allowed formats: {settings.ALLOWED_EXTENSIONS}"
            )

        # Check file size
        file_size = file_path.stat().st_size
        if file_size > settings.MAX_FILE_SIZE:
            raise ValueError(
                f"File size ({file_size} bytes) exceeds maximum "
                f"allowed size ({settings.MAX_FILE_SIZE} bytes)"
            )

        # Try to get duration (validates if file is readable)
        try:
            duration = get_audio_duration(file_path)
            if duration <= 0:
                raise ValueError("Audio file has zero or negative duration")
        except Exception as e:
            raise ValueError(f"Unable to read audio file: {e}")

        logger.info(f"Audio file validated: {file_path}")
        return True

    def extract_audio_segment(
        self,
        audio: np.ndarray,
        sr: int,
        start_time: float,
        end_time: float
    ) -> np.ndarray:
        """
        Extract a segment from audio array.

        Args:
            audio: Full audio array
            sr: Sample rate
            start_time: Start time in seconds
            end_time: End time in seconds

        Returns:
            Audio segment array
        """
        start_sample = int(start_time * sr)
        end_sample = int(end_time * sr)

        # Ensure valid range
        start_sample = max(0, start_sample)
        end_sample = min(len(audio), end_sample)

        segment = audio[start_sample:end_sample]
        return segment

    def prepare_for_diarization(self, file_path: str | Path) -> dict:
        """
        Prepare audio file for speaker diarization.

        Args:
            file_path: Path to audio file

        Returns:
            Dictionary with audio info and prepared data
        """
        try:
            # Validate file
            self.validate_audio_file(file_path)

            # Process audio
            audio, sr, duration = self.process_audio_file(file_path)

            return {
                "file_path": str(file_path),
                "audio": audio,
                "sample_rate": sr,
                "duration": duration,
                "success": True
            }

        except Exception as e:
            logger.error(f"Error preparing audio for diarization: {e}")
            return {
                "file_path": str(file_path),
                "success": False,
                "error": str(e)
            }
