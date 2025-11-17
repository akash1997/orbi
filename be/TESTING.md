# Testing Documentation

Comprehensive test suite for the Orbi Speaker Intelligence API.

## Test Structure

```
tests/
├── conftest.py              # Pytest fixtures and configuration
├── test_audio_utils.py      # Audio processing utilities tests
├── test_database.py         # Database models tests
├── test_vector_store.py     # Vector store tests
├── test_speaker_manager.py  # Speaker management tests
├── test_api.py              # API endpoint tests
└── test_integration.py      # Integration tests
```

## Running Tests

### Quick Start

```bash
# Run all tests
uv run pytest tests/ -v

# Run with coverage
uv run pytest tests/ --cov=. --cov-report=html

# Use the test runner script
chmod +x run_tests.sh
./run_tests.sh
```

### Test Categories

Tests are marked with categories:

```bash
# Unit tests only
uv run pytest tests/ -m unit -v

# Integration tests only
uv run pytest tests/ -m integration -v

# Slow tests (require ML models)
uv run pytest tests/ -m slow -v

# Tests requiring API keys
uv run pytest tests/ -m requires_api -v
```

### Specific Test Files

```bash
# Test audio utilities
uv run pytest tests/test_audio_utils.py -v

# Test database operations
uv run pytest tests/test_database.py -v

# Test API endpoints
uv run pytest tests/test_api.py -v

# Test vector store
uv run pytest tests/test_vector_store.py -v
```

## Test Coverage

### Unit Tests (67 tests)

**Audio Utilities** (`test_audio_utils.py`)
- ✅ `test_load_audio` - Loading audio files
- ✅ `test_get_audio_duration` - Getting audio duration
- ✅ `test_normalize_audio` - Audio normalization
- ✅ `test_normalize_audio_zero` - Edge case: zero audio
- ✅ `test_compute_rms_energy` - RMS energy computation
- ✅ `test_detect_silence` - Silence detection

**Database Models** (`test_database.py`)
- ✅ `test_create_speaker` - Creating speaker records
- ✅ `test_create_audio_file` - Creating audio file records
- ✅ `test_speaker_audio_file_association` - Speaker-file associations
- ✅ `test_speaker_segment` - Creating speaker segments
- ✅ `test_conversation_insight` - Conversation insights
- ✅ `test_speaker_insight` - Speaker-specific insights
- ✅ `test_processing_job` - Processing job tracking
- ✅ `test_speaker_update_stats` - Updating speaker statistics
- ✅ `test_query_speaker_files` - Querying speaker files

**Vector Store** (`test_vector_store.py`)
- ✅ `test_vector_store_initialization` - Vector store setup
- ✅ `test_add_embedding` - Adding embeddings
- ✅ `test_add_multiple_embeddings` - Multiple embeddings
- ✅ `test_search_embeddings` - Similarity search
- ✅ `test_find_matching_speaker` - Speaker matching
- ✅ `test_no_matching_speaker` - No match scenarios
- ✅ `test_save_and_load` - Persistence
- ✅ `test_remove_speaker` - Speaker removal

**Speaker Manager** (`test_speaker_manager.py`)
- ✅ `test_create_speaker` - Creating speakers
- ✅ `test_create_speaker_default_name` - Default naming
- ✅ `test_get_speaker` - Retrieving speakers
- ✅ `test_get_nonexistent_speaker` - Error handling
- ✅ `test_list_speakers` - Listing all speakers
- ✅ `test_update_speaker` - Updating speaker info
- ✅ `test_identify_or_create_speaker_new` - New speaker identification
- ✅ `test_identify_or_create_speaker_existing` - Existing speaker matching
- ✅ `test_update_speaker_stats` - Statistics updates
- ✅ `test_create_speaker_audio_association` - Creating associations
- ✅ `test_get_speaker_files` - Getting speaker files
- ✅ `test_merge_speakers` - Merging duplicate speakers
- ✅ `test_delete_speaker` - Deleting speakers

**API Endpoints** (`test_api.py`)
- ✅ `test_root_endpoint` - Root endpoint
- ✅ `test_health_check` - Health check
- ✅ `test_upload_audio_file` - File upload
- ✅ `test_upload_invalid_file_type` - Invalid file handling
- ✅ `test_get_job_status` - Job status checking
- ✅ `test_get_nonexistent_job` - Error handling
- ✅ `test_list_recordings` - Listing recordings
- ✅ `test_list_speakers` - Listing speakers
- ✅ `test_get_speaker_details` - Speaker details
- ✅ `test_get_nonexistent_speaker` - Error handling
- ✅ `test_update_speaker` - Updating speaker
- ✅ `test_merge_speakers` - Merging speakers
- ✅ `test_delete_speaker` - Deleting speaker
- ✅ `test_upload_with_duplicate_filename` - Duplicate handling
- ✅ `test_get_recording_not_processed` - Processing status
- ✅ `test_pagination_speakers` - Pagination

### Integration Tests (6 tests)

**Full Pipeline** (`test_integration.py`)
- ✅ `test_audio_processing_pipeline` - End-to-end audio processing
- ✅ `test_speaker_identification_pipeline` - Cross-file speaker matching
- ✅ `test_word_count_analysis` - Transcript analysis
- ✅ `test_end_to_end_speaker_tracking` - Complete workflow
- ✅ `test_multi_speaker_conversation` - Multiple speakers
- ✅ `test_speaker_merge_workflow` - Duplicate merging

## Test Fixtures

### Database Fixtures
- `test_db_engine` - In-memory SQLite database
- `db_session` - Database session for each test
- `test_vector_store` - Temporary vector store

### Audio Fixtures
- `sample_audio_array` - Generated audio data (1 second sine wave)
- `sample_audio_file` - Temporary WAV file
- `sample_embedding` - Random speaker embedding (192-dim)

### Mock Data Fixtures
- `mock_speaker_data` - Mock speaker information
- `mock_conversation_transcript` - Sample transcript
- `mock_llm_insights` - Mock LLM-generated insights
- `mock_speaker_insights` - Mock speaker analysis

### API Fixtures
- `client` - FastAPI test client
- `test_upload_dir` - Temporary upload directory

## Writing New Tests

### Unit Test Template

```python
import pytest

@pytest.mark.unit
def test_my_function(db_session):
    """Test description."""
    # Arrange
    input_data = "test"

    # Act
    result = my_function(input_data)

    # Assert
    assert result == expected_output
```

### Integration Test Template

```python
import pytest

@pytest.mark.integration
def test_my_workflow(db_session, test_vector_store):
    """Test end-to-end workflow."""
    # Setup
    ...

    # Execute workflow
    ...

    # Verify results
    assert ...
```

### Slow Test (Requires Models)

```python
import pytest

@pytest.mark.slow
def test_with_real_model():
    """Test that requires actual ML models."""
    # This test will be skipped by default
    ...
```

### Test Requiring API Keys

```python
import pytest

@pytest.mark.requires_api
def test_llm_integration():
    """Test that requires API keys."""
    # This test requires OPENAI_API_KEY or ANTHROPIC_API_KEY
    ...
```

## Continuous Integration

### GitHub Actions

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      - name: Install dependencies
        run: |
          pip install uv
          uv sync
      - name: Run tests
        run: uv run pytest tests/ -v --cov
```

## Test Coverage Goals

- **Unit Tests**: > 80% coverage
- **Integration Tests**: Cover all major workflows
- **API Tests**: All endpoints tested
- **Edge Cases**: Error handling, invalid inputs

## Common Testing Patterns

### Testing with Mock Data

```python
@pytest.fixture
def mock_llm_response():
    return {
        "summary": "Test summary",
        "sentiment": "positive"
    }

def test_with_mock(mocker, mock_llm_response):
    mocker.patch('services.llm_client.LLMClient.generate_insights',
                 return_value=mock_llm_response)
    # Test code
```

### Testing Async Functions

```python
@pytest.mark.asyncio
async def test_async_function():
    result = await my_async_function()
    assert result is not None
```

### Testing Database Transactions

```python
def test_database_rollback(db_session):
    # Create test data
    speaker = Speaker(name="Test")
    db_session.add(speaker)
    db_session.commit()

    # Rollback happens automatically after test
```

## Troubleshooting

### Tests Not Found
```bash
# Check pytest can discover tests
uv run pytest --collect-only
```

### Import Errors
```bash
# Reinstall dependencies
uv sync --reinstall
```

### Database Lock Errors
```bash
# Tests use in-memory SQLite - shouldn't happen
# If it does, check for unclosed sessions
```

### Slow Tests
```bash
# Skip slow tests that load ML models
uv run pytest tests/ -m "not slow"
```

## Performance Benchmarks

### Expected Test Times

- Unit tests: ~5-10 seconds
- Integration tests: ~10-20 seconds
- Full suite: ~20-30 seconds (without ML models)

### With ML Models

- Diarization tests: ~30-60 seconds per test
- Transcription tests: ~20-40 seconds per test
- Full pipeline: ~2-5 minutes per test

## Best Practices

1. **Isolation**: Each test should be independent
2. **Fixtures**: Use fixtures for common setup
3. **Mocking**: Mock external services (APIs, ML models)
4. **Coverage**: Aim for > 80% code coverage
5. **Speed**: Keep unit tests fast (< 1 second each)
6. **Documentation**: Clear docstrings for each test
7. **Assertions**: Use descriptive assertion messages
8. **Cleanup**: Tests should clean up after themselves

## Debugging Tests

### Run Single Test

```bash
uv run pytest tests/test_api.py::test_upload_audio_file -v
```

### Print Debug Output

```bash
uv run pytest tests/ -v -s  # -s shows print statements
```

### Drop into Debugger

```python
def test_my_function():
    result = my_function()
    import pdb; pdb.set_trace()  # Debugger breakpoint
    assert result == expected
```

### Verbose Output

```bash
uv run pytest tests/ -vv --tb=long
```

## Maintenance

### Updating Tests

When adding new features:
1. Write tests first (TDD)
2. Run tests to verify they fail
3. Implement feature
4. Run tests to verify they pass
5. Update coverage report

### Regression Tests

When fixing bugs:
1. Write a test that reproduces the bug
2. Fix the bug
3. Verify test passes
4. Keep test to prevent regression

## Resources

- [pytest Documentation](https://docs.pytest.org/)
- [pytest-cov Documentation](https://pytest-cov.readthedocs.io/)
- [FastAPI Testing](https://fastapi.tiangolo.com/tutorial/testing/)
- [SQLAlchemy Testing](https://docs.sqlalchemy.org/en/latest/orm/session_basics.html#session-frequently-asked-questions)
