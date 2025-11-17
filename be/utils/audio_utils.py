"""Audio utility functions."""
import librosa
import soundfile as sf
import numpy as np
from pathlib import Path
from typing import Tuple
import logging

logger = logging.getLogger(__name__)


def load_audio(
    file_path: str | Path,
    target_sr: int = 16000
) -> Tuple[np.ndarray, int]:
    """
    Load audio file and resample to target sample rate.

    Args:
        file_path: Path to audio file
        target_sr: Target sample rate (default 16kHz for speech models)

    Returns:
        Tuple of (audio_array, sample_rate)
    """
    try:
        audio, sr = librosa.load(str(file_path), sr=target_sr, mono=True)
        logger.debug(f"Loaded audio: {file_path}, duration: {len(audio)/sr:.2f}s")
        return audio, sr
    except Exception as e:
        logger.error(f"Error loading audio {file_path}: {e}")
        raise


def get_audio_duration(file_path: str | Path) -> float:
    """
    Get audio file duration in seconds.

    Args:
        file_path: Path to audio file

    Returns:
        Duration in seconds
    """
    try:
        duration = librosa.get_duration(path=str(file_path))
        return duration
    except Exception as e:
        logger.error(f"Error getting duration for {file_path}: {e}")
        raise


def save_audio_segment(
    audio: np.ndarray,
    sr: int,
    output_path: str | Path,
    start_time: float = None,
    end_time: float = None
) -> Path:
    """
    Save audio segment to file.

    Args:
        audio: Audio array
        sr: Sample rate
        output_path: Output file path
        start_time: Start time in seconds (optional)
        end_time: End time in seconds (optional)

    Returns:
        Path to saved file
    """
    try:
        if start_time is not None and end_time is not None:
            start_sample = int(start_time * sr)
            end_sample = int(end_time * sr)
            audio = audio[start_sample:end_sample]

        output_path = Path(output_path)
        sf.write(str(output_path), audio, sr)
        logger.debug(f"Saved audio segment to {output_path}")
        return output_path
    except Exception as e:
        logger.error(f"Error saving audio segment: {e}")
        raise


def normalize_audio(audio: np.ndarray) -> np.ndarray:
    """
    Normalize audio to [-1, 1] range.

    Args:
        audio: Audio array

    Returns:
        Normalized audio array
    """
    max_val = np.abs(audio).max()
    if max_val > 0:
        audio = audio / max_val
    return audio


def compute_rms_energy(audio: np.ndarray, frame_length: int = 2048) -> np.ndarray:
    """
    Compute RMS energy for audio signal.

    Args:
        audio: Audio array
        frame_length: Frame length for RMS computation

    Returns:
        RMS energy array
    """
    return librosa.feature.rms(y=audio, frame_length=frame_length)[0]


def detect_silence(
    audio: np.ndarray,
    sr: int,
    threshold_db: float = -40.0,
    min_silence_duration: float = 0.5
) -> list:
    """
    Detect silence segments in audio.

    Args:
        audio: Audio array
        sr: Sample rate
        threshold_db: Silence threshold in dB
        min_silence_duration: Minimum silence duration in seconds

    Returns:
        List of (start_time, end_time) tuples for silence segments
    """
    # Compute RMS energy
    rms = librosa.feature.rms(y=audio)[0]

    # Convert to dB
    rms_db = librosa.amplitude_to_db(rms, ref=np.max)

    # Find silence frames
    silence_frames = rms_db < threshold_db

    # Convert frames to time
    frame_times = librosa.frames_to_time(np.arange(len(rms)), sr=sr)

    # Find contiguous silence regions
    silence_regions = []
    in_silence = False
    start_time = None

    for i, is_silence in enumerate(silence_frames):
        if is_silence and not in_silence:
            start_time = frame_times[i]
            in_silence = True
        elif not is_silence and in_silence:
            end_time = frame_times[i]
            if end_time - start_time >= min_silence_duration:
                silence_regions.append((start_time, end_time))
            in_silence = False

    return silence_regions


def convert_to_wav(input_path: str | Path, output_path: str | Path = None) -> Path:
    """
    Convert audio file to WAV format for compatibility with soundfile.

    This is needed because pyannote.audio uses soundfile as backend,
    which doesn't support M4A/AAC formats. We use librosa to load
    (which supports many formats via audioread/ffmpeg) and save as WAV.

    Args:
        input_path: Path to input audio file
        output_path: Path for output WAV file (optional, auto-generated if None)

    Returns:
        Path to converted WAV file
    """
    try:
        input_path = Path(input_path)

        # Generate output path if not provided
        if output_path is None:
            output_path = input_path.with_suffix('.wav')
        else:
            output_path = Path(output_path)

        # If already WAV, just return the path
        if input_path.suffix.lower() == '.wav':
            logger.debug(f"File is already WAV format: {input_path}")
            return input_path

        # Load audio using librosa (supports many formats via ffmpeg/audioread)
        audio, sr = librosa.load(str(input_path), sr=None, mono=False)

        # Save as WAV using soundfile
        sf.write(str(output_path), audio.T if audio.ndim > 1 else audio, sr)

        logger.info(f"Converted {input_path} to WAV: {output_path}")
        return output_path

    except Exception as e:
        logger.error(f"Error converting audio to WAV: {e}")
        raise
