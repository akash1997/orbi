"""Tests for vector store operations."""
import pytest
import numpy as np
from database.vector_store import VectorStore


@pytest.mark.unit
def test_vector_store_initialization(test_vector_store):
    """Test vector store initialization."""
    assert test_vector_store.index is not None
    assert test_vector_store.dimension == 192
    assert test_vector_store.get_total_embeddings() == 0


@pytest.mark.unit
def test_add_embedding(test_vector_store, sample_embedding):
    """Test adding an embedding to the vector store."""
    speaker_id = "speaker_001"
    segment_id = "segment_001"
    audio_file_id = "file_001"

    index = test_vector_store.add_embedding(
        sample_embedding,
        speaker_id,
        segment_id,
        audio_file_id
    )

    assert index == 0
    assert test_vector_store.get_total_embeddings() == 1
    assert test_vector_store.get_speaker_embeddings_count(speaker_id) == 1


@pytest.mark.unit
def test_add_multiple_embeddings(test_vector_store):
    """Test adding multiple embeddings."""
    for i in range(5):
        embedding = np.random.randn(192).astype('float32')
        test_vector_store.add_embedding(
            embedding,
            f"speaker_{i % 2}",  # Two speakers
            f"segment_{i}",
            "audio_001"
        )

    assert test_vector_store.get_total_embeddings() == 5
    assert test_vector_store.get_speaker_embeddings_count("speaker_0") == 3
    assert test_vector_store.get_speaker_embeddings_count("speaker_1") == 2


@pytest.mark.unit
def test_search_embeddings(test_vector_store):
    """Test searching for similar embeddings."""
    # Add some embeddings
    base_embedding = np.random.randn(192).astype('float32')

    # Add similar embeddings for speaker_001
    for i in range(3):
        # Add small noise to make similar but not identical
        similar_embedding = base_embedding + np.random.randn(192).astype('float32') * 0.01
        test_vector_store.add_embedding(
            similar_embedding,
            "speaker_001",
            f"segment_{i}",
            "audio_001"
        )

    # Add different embedding for speaker_002
    different_embedding = np.random.randn(192).astype('float32')
    test_vector_store.add_embedding(
        different_embedding,
        "speaker_002",
        "segment_999",
        "audio_002"
    )

    # Search with query similar to base embedding
    query = base_embedding + np.random.randn(192).astype('float32') * 0.01
    results = test_vector_store.search(query, k=4)

    assert len(results) == 4
    # First result should be one of speaker_001's embeddings (higher similarity)
    assert results[0][0] == "speaker_001"


@pytest.mark.unit
def test_find_matching_speaker(test_vector_store):
    """Test finding matching speaker."""
    # Add embeddings for a speaker
    speaker_id = "speaker_001"
    base_embedding = np.random.randn(192).astype('float32')

    for i in range(5):
        similar_embedding = base_embedding + np.random.randn(192).astype('float32') * 0.1
        test_vector_store.add_embedding(
            similar_embedding,
            speaker_id,
            f"segment_{i}",
            "audio_001"
        )

    # Query with very similar embedding
    query = base_embedding + np.random.randn(192).astype('float32') * 0.05
    match = test_vector_store.find_matching_speaker(query, similarity_threshold=0.5)

    assert match is not None
    matched_speaker_id, similarity = match
    assert matched_speaker_id == speaker_id
    assert similarity > 0.5


@pytest.mark.unit
def test_no_matching_speaker(test_vector_store):
    """Test when no speaker matches."""
    # Add one embedding
    embedding1 = np.random.randn(192).astype('float32')
    test_vector_store.add_embedding(embedding1, "speaker_001", "seg_1", "audio_1")

    # Query with very different embedding
    query = np.random.randn(192).astype('float32')

    # Use very high threshold
    match = test_vector_store.find_matching_speaker(query, similarity_threshold=0.99)

    # Should not match
    assert match is None


@pytest.mark.unit
def test_save_and_load(test_vector_store, sample_embedding, tmp_path):
    """Test saving and loading vector store."""
    # Add some embeddings
    test_vector_store.add_embedding(sample_embedding, "speaker_001", "seg_1", "audio_1")
    test_vector_store.add_embedding(sample_embedding * 2, "speaker_002", "seg_2", "audio_2")

    # Save
    test_vector_store.save()

    # Create new vector store and load
    new_store = VectorStore(dimension=192, index_path=test_vector_store.index_path)

    assert new_store.get_total_embeddings() == 2
    assert new_store.get_speaker_embeddings_count("speaker_001") == 1
    assert new_store.get_speaker_embeddings_count("speaker_002") == 1


@pytest.mark.unit
def test_remove_speaker(test_vector_store):
    """Test removing a speaker's embeddings."""
    # Add embeddings for two speakers
    for i in range(3):
        embedding = np.random.randn(192).astype('float32')
        test_vector_store.add_embedding(embedding, "speaker_001", f"seg_{i}", "audio_1")

    for i in range(2):
        embedding = np.random.randn(192).astype('float32')
        test_vector_store.add_embedding(embedding, "speaker_002", f"seg_{i}", "audio_2")

    # Remove speaker_001
    test_vector_store.remove_speaker("speaker_001")

    # speaker_001 should be marked as deleted
    assert "speaker_001" not in test_vector_store.speaker_to_indices
    assert "speaker_002" in test_vector_store.speaker_to_indices
