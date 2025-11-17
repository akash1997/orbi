"""Speaker diarization service using pyannote.audio."""
import logging
from pathlib import Path
from typing import List, Dict, Any
import torch
from pyannote.audio import Pipeline
from pyannote.audio.pipelines.speaker_verification import PretrainedSpeakerEmbedding
import numpy as np
from config import settings
from utils.audio_utils import convert_to_wav

logger = logging.getLogger(__name__)


class SpeakerDiarizationService:
    """Service for speaker diarization using pyannote.audio."""

    def __init__(self):
        """Initialize diarization service."""
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        logger.info(f"Using device: {self.device}")

        # Load diarization pipeline
        try:
            self.pipeline = Pipeline.from_pretrained(
                settings.DIARIZATION_MODEL,
                use_auth_token=settings.HF_TOKEN
            )
            self.pipeline.to(self.device)
            logger.info(f"Loaded diarization model: {settings.DIARIZATION_MODEL}")
        except Exception as e:
            logger.error(f"Error loading diarization model: {e}")
            logger.warning("Diarization pipeline not loaded. Ensure HF_TOKEN is set.")
            self.pipeline = None

        # Load embedding model
        try:
            self.embedding_model = PretrainedSpeakerEmbedding(
                settings.SPEAKER_EMBEDDING_MODEL,
                device=self.device,
                use_auth_token=settings.HF_TOKEN
            )
            logger.info(f"Loaded embedding model: {settings.SPEAKER_EMBEDDING_MODEL}")
        except Exception as e:
            logger.error(f"Error loading embedding model: {e}")
            self.embedding_model = None

    def diarize(self, audio_file_path: str | Path) -> List[Dict[str, Any]]:
        """
        Perform speaker diarization on audio file.

        Args:
            audio_file_path: Path to audio file

        Returns:
            List of diarization segments with speaker labels
        """
        if self.pipeline is None:
            raise RuntimeError("Diarization pipeline not loaded. Check HF_TOKEN.")

        try:
            # Convert to WAV if needed (pyannote uses soundfile which doesn't support M4A)
            wav_path = convert_to_wav(audio_file_path)
            audio_file_path = str(wav_path)

            # Run diarization
            diarization = self.pipeline(audio_file_path)

            # Extract segments
            segments = []
            for turn, _, speaker in diarization.itertracks(yield_label=True):
                segments.append({
                    "start": turn.start,
                    "end": turn.end,
                    "duration": turn.end - turn.start,
                    "speaker_label": speaker,  # Temporary label from diarization
                    "confidence": 1.0  # pyannote doesn't provide confidence scores directly
                })

            logger.info(f"Diarization complete: {len(segments)} segments, "
                       f"{len(set(s['speaker_label'] for s in segments))} speakers")

            return segments

        except Exception as e:
            logger.error(f"Error during diarization: {e}")
            raise

    def extract_embedding(
        self,
        audio_file_path: str | Path,
        start_time: float,
        end_time: float
    ) -> np.ndarray:
        """
        Extract speaker embedding for a specific time segment.

        Args:
            audio_file_path: Path to audio file
            start_time: Segment start time in seconds
            end_time: Segment end time in seconds

        Returns:
            Speaker embedding as numpy array
        """
        if self.embedding_model is None:
            raise RuntimeError("Embedding model not loaded. Check HF_TOKEN.")

        try:
            from pyannote.core import Segment
            from pyannote.audio import Audio

            # Convert to WAV if needed
            wav_path = convert_to_wav(audio_file_path)
            audio_file_path = str(wav_path)

            # Create segment
            segment = Segment(start_time, end_time)

            # Load audio segment
            audio = Audio(sample_rate=16000, mono=True)
            waveform, sample_rate = audio.crop(audio_file_path, segment)

            # Extract embedding
            with torch.no_grad():
                embedding = self.embedding_model(waveform.unsqueeze(0).to(self.device))
                embedding = embedding.cpu().numpy().flatten()

            logger.debug(f"Extracted embedding for segment [{start_time:.2f}, {end_time:.2f}]")
            return embedding

        except Exception as e:
            logger.error(f"Error extracting embedding: {e}")
            raise

    def extract_embeddings_batch(
        self,
        audio_file_path: str | Path,
        segments: List[Dict[str, Any]]
    ) -> List[np.ndarray]:
        """
        Extract embeddings for multiple segments.

        Args:
            audio_file_path: Path to audio file
            segments: List of segment dictionaries with 'start' and 'end' keys

        Returns:
            List of speaker embeddings
        """
        embeddings = []

        for segment in segments:
            try:
                embedding = self.extract_embedding(
                    audio_file_path,
                    segment['start'],
                    segment['end']
                )
                embeddings.append(embedding)
            except Exception as e:
                logger.warning(f"Failed to extract embedding for segment "
                             f"[{segment['start']:.2f}, {segment['end']:.2f}]: {e}")
                # Use zero embedding as fallback
                embeddings.append(np.zeros(settings.EMBEDDING_DIMENSION))

        return embeddings

    def merge_short_segments(
        self,
        segments: List[Dict[str, Any]],
        min_duration: float = 1.0
    ) -> List[Dict[str, Any]]:
        """
        Merge consecutive segments from the same speaker that are too short.

        Args:
            segments: List of diarization segments
            min_duration: Minimum segment duration in seconds

        Returns:
            List of merged segments
        """
        if not segments:
            return []

        merged = []
        current = segments[0].copy()

        for segment in segments[1:]:
            # If same speaker and gap is small, merge
            if (segment['speaker_label'] == current['speaker_label'] and
                segment['start'] - current['end'] < 0.5):
                current['end'] = segment['end']
                current['duration'] = current['end'] - current['start']
            else:
                # Save current if it meets duration threshold
                if current['duration'] >= min_duration:
                    merged.append(current)
                current = segment.copy()

        # Add last segment
        if current['duration'] >= min_duration:
            merged.append(current)

        logger.info(f"Merged {len(segments)} segments into {len(merged)} segments")
        return merged

    def get_speaker_statistics(self, segments: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Get statistics about speakers in the diarization.

        Args:
            segments: List of diarization segments

        Returns:
            Dictionary with speaker statistics
        """
        if not segments:
            return {"total_speakers": 0, "speakers": {}}

        speakers = {}
        for segment in segments:
            speaker_label = segment['speaker_label']
            if speaker_label not in speakers:
                speakers[speaker_label] = {
                    "total_duration": 0.0,
                    "segment_count": 0,
                    "segments": []
                }

            speakers[speaker_label]["total_duration"] += segment['duration']
            speakers[speaker_label]["segment_count"] += 1
            speakers[speaker_label]["segments"].append({
                "start": segment['start'],
                "end": segment['end']
            })

        return {
            "total_speakers": len(speakers),
            "speakers": speakers
        }
