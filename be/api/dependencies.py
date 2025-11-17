"""FastAPI dependencies."""
from database.session import get_db
from database.vector_store import VectorStore

# Re-export database dependency
__all__ = ["get_db", "get_vector_store"]


def get_vector_store() -> VectorStore:
    """Get vector store instance."""
    return VectorStore()
