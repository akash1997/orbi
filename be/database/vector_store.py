"""Vector store for speaker embeddings using FAISS."""
import faiss
import numpy as np
import pickle
from pathlib import Path
from typing import List, Tuple, Optional, Dict
from config import settings
import logging

logger = logging.getLogger(__name__)


class VectorStore:
    """
    Vector store for storing and searching speaker embeddings using FAISS.

    This class manages a FAISS index for efficient similarity search of speaker
    embeddings.
    """

    def __init__(self, dimension: int = None, index_path: Path = None):
        """
        Initialize vector store.

        Args:
            dimension: Embedding dimension (default from settings)
            index_path: Path to store index files (default from settings)
        """
        self.dimension = dimension or settings.EMBEDDING_DIMENSION
        self.index_path = index_path or settings.VECTOR_DB_PATH
        self.index_file = self.index_path / "speaker_embeddings.index"
        self.metadata_file = self.index_path / "speaker_metadata.pkl"

        # Ensure directory exists
        self.index_path.mkdir(parents=True, exist_ok=True)

        # Initialize or load index
        self.index = None
        self.metadata: Dict[int, Dict] = {}  # Maps index position to metadata
        self.speaker_to_indices: Dict[str, List[int]] = {}  # Maps speaker_id to index positions
        self._load_or_create_index()

    def _load_or_create_index(self):
        """Load existing index or create a new one."""
        if self.index_file.exists() and self.metadata_file.exists():
            try:
                self.index = faiss.read_index(str(self.index_file))
                with open(self.metadata_file, 'rb') as f:
                    data = pickle.load(f)
                    self.metadata = data.get('metadata', {})
                    self.speaker_to_indices = data.get('speaker_to_indices', {})
                logger.info(f"Loaded existing FAISS index with {self.index.ntotal} vectors")
            except Exception as e:
                logger.error(f"Error loading index: {e}. Creating new index.")
                self._create_new_index()
        else:
            self._create_new_index()

    def _create_new_index(self):
        """Create a new FAISS index."""
        # Using IndexFlatIP for inner product (cosine similarity with normalized vectors)
        self.index = faiss.IndexFlatIP(self.dimension)
        self.metadata = {}
        self.speaker_to_indices = {}
        logger.info(f"Created new FAISS index with dimension {self.dimension}")

    def save(self):
        """Save index and metadata to disk."""
        try:
            faiss.write_index(self.index, str(self.index_file))
            with open(self.metadata_file, 'wb') as f:
                pickle.dump({
                    'metadata': self.metadata,
                    'speaker_to_indices': self.speaker_to_indices
                }, f)
            logger.info("Saved FAISS index and metadata")
        except Exception as e:
            logger.error(f"Error saving index: {e}")
            raise

    def add_embedding(
        self,
        embedding: np.ndarray,
        speaker_id: str,
        segment_id: str,
        audio_file_id: str
    ) -> int:
        """
        Add a speaker embedding to the index.

        Args:
            embedding: Speaker embedding vector
            speaker_id: Speaker ID
            segment_id: Segment ID
            audio_file_id: Audio file ID

        Returns:
            Index position of the added embedding
        """
        # Normalize embedding for cosine similarity
        embedding = embedding.reshape(1, -1).astype('float32')
        faiss.normalize_L2(embedding)

        # Add to index
        current_index = self.index.ntotal
        self.index.add(embedding)

        # Store metadata
        self.metadata[current_index] = {
            'speaker_id': speaker_id,
            'segment_id': segment_id,
            'audio_file_id': audio_file_id
        }

        # Update speaker to indices mapping
        if speaker_id not in self.speaker_to_indices:
            self.speaker_to_indices[speaker_id] = []
        self.speaker_to_indices[speaker_id].append(current_index)

        logger.debug(f"Added embedding for speaker {speaker_id} at index {current_index}")
        return current_index

    def search(
        self,
        query_embedding: np.ndarray,
        k: int = 5
    ) -> List[Tuple[str, float, Dict]]:
        """
        Search for similar embeddings.

        Args:
            query_embedding: Query embedding vector
            k: Number of nearest neighbors to return

        Returns:
            List of tuples (speaker_id, similarity_score, metadata)
        """
        if self.index.ntotal == 0:
            return []

        # Normalize query embedding
        query_embedding = query_embedding.reshape(1, -1).astype('float32')
        faiss.normalize_L2(query_embedding)

        # Search
        k = min(k, self.index.ntotal)
        similarities, indices = self.index.search(query_embedding, k)

        # Format results
        results = []
        for similarity, idx in zip(similarities[0], indices[0]):
            if idx == -1:  # FAISS returns -1 for empty slots
                continue
            metadata = self.metadata.get(idx, {})
            speaker_id = metadata.get('speaker_id')
            if speaker_id:
                results.append((speaker_id, float(similarity), metadata))

        return results

    def find_matching_speaker(
        self,
        query_embedding: np.ndarray,
        similarity_threshold: float = None
    ) -> Optional[Tuple[str, float]]:
        """
        Find the best matching speaker for a query embedding.

        Args:
            query_embedding: Query embedding vector
            similarity_threshold: Minimum similarity threshold (default from settings)

        Returns:
            Tuple of (speaker_id, similarity_score) or None if no match above threshold
        """
        threshold = similarity_threshold or settings.SPEAKER_SIMILARITY_THRESHOLD

        results = self.search(query_embedding, k=10)
        if not results:
            return None

        # Group by speaker and find average similarity
        speaker_similarities: Dict[str, List[float]] = {}
        for speaker_id, similarity, _ in results:
            if speaker_id not in speaker_similarities:
                speaker_similarities[speaker_id] = []
            speaker_similarities[speaker_id].append(similarity)

        # Find best matching speaker
        best_speaker = None
        best_similarity = 0.0

        for speaker_id, similarities in speaker_similarities.items():
            avg_similarity = np.mean(similarities)
            if avg_similarity > best_similarity:
                best_similarity = avg_similarity
                best_speaker = speaker_id

        if best_similarity >= threshold:
            logger.info(f"Found matching speaker {best_speaker} with similarity {best_similarity:.3f}")
            return (best_speaker, best_similarity)

        logger.info(f"No matching speaker found above threshold {threshold:.3f} (best: {best_similarity:.3f})")
        return None

    def get_speaker_embeddings_count(self, speaker_id: str) -> int:
        """
        Get the number of embeddings for a speaker.

        Args:
            speaker_id: Speaker ID

        Returns:
            Number of embeddings
        """
        return len(self.speaker_to_indices.get(speaker_id, []))

    def remove_speaker(self, speaker_id: str):
        """
        Remove all embeddings for a speaker.

        Note: FAISS doesn't support efficient removal, so this marks for rebuild.
        For production, consider using IndexIDMap for better management.

        Args:
            speaker_id: Speaker ID to remove
        """
        if speaker_id in self.speaker_to_indices:
            # Mark metadata as deleted
            for idx in self.speaker_to_indices[speaker_id]:
                if idx in self.metadata:
                    self.metadata[idx]['deleted'] = True
            del self.speaker_to_indices[speaker_id]
            logger.info(f"Marked embeddings for speaker {speaker_id} as deleted")

    def get_total_embeddings(self) -> int:
        """Get total number of embeddings in the index."""
        return self.index.ntotal

    def rebuild_index(self):
        """
        Rebuild index excluding deleted embeddings.

        This should be called periodically to clean up deleted embeddings.
        """
        # Collect non-deleted embeddings
        valid_embeddings = []
        valid_metadata = {}

        for idx, meta in self.metadata.items():
            if not meta.get('deleted', False):
                # Note: We'd need to store original embeddings to rebuild
                # For now, this is a placeholder for future enhancement
                pass

        logger.warning("Index rebuild not fully implemented. Consider using IndexIDMap for production.")
