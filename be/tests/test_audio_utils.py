"""Tests for audio utility functions."""
import pytest
import numpy as np
from utils.audio_utils import (
    load_audio,
    get_audio_duration,
    normalize_audio,
    compute_rms_energy,
    detect_silence
)


@pytest.mark.unit
def test_load_audio(sample_audio_file):
    """Test loading audio file."""
    audio, sr = load_audio(sample_audio_file)

    assert isinstance(audio, np.ndarray)
    assert sr == 16000
    assert len(audio) > 0
    assert audio.dtype == np.float32


@pytest.mark.unit
def test_get_audio_duration(sample_audio_file):
    """Test getting audio duration."""
    duration = get_audio_duration(sample_audio_file)

    assert isinstance(duration, float)
    assert duration > 0
    assert duration < 2.0  # Should be around 1 second


@pytest.mark.unit
def test_normalize_audio():
    """Test audio normalization."""
    audio = np.array([0.5, 1.0, -0.5, -1.0])
    normalized = normalize_audio(audio)

    assert normalized.max() <= 1.0
    assert normalized.min() >= -1.0
    assert np.abs(normalized.max()) == 1.0 or np.abs(normalized.min()) == 1.0


@pytest.mark.unit
def test_normalize_audio_zero():
    """Test normalizing zero audio."""
    audio = np.zeros(100)
    normalized = normalize_audio(audio)

    assert np.all(normalized == 0)


@pytest.mark.unit
def test_compute_rms_energy(sample_audio_array):
    """Test RMS energy computation."""
    audio, _ = sample_audio_array
    rms = compute_rms_energy(audio)

    assert isinstance(rms, np.ndarray)
    assert len(rms) > 0
    assert np.all(rms >= 0)


@pytest.mark.unit
def test_detect_silence():
    """Test silence detection."""
    # Create audio with silence in the middle
    sr = 16000
    duration = 3.0

    # Loud section
    t1 = np.linspace(0, 1, sr)
    loud = np.sin(2 * np.pi * 440 * t1)

    # Silent section
    silence = np.zeros(sr)

    # Another loud section
    t2 = np.linspace(0, 1, sr)
    loud2 = np.sin(2 * np.pi * 440 * t2)

    # Combine
    audio = np.concatenate([loud, silence, loud2])

    silence_regions = detect_silence(audio, sr, threshold_db=-40, min_silence_duration=0.5)

    assert isinstance(silence_regions, list)
    # Should detect the silence in the middle
    assert len(silence_regions) > 0
