"""Tests for API endpoints."""
import pytest
import io
from database.models import ProcessingJob, AudioFile, Speaker, ProcessingStatus


@pytest.mark.unit
def test_root_endpoint(client):
    """Test root endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "endpoints" in data


@pytest.mark.unit
def test_health_check(client):
    """Test health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"


@pytest.mark.unit
def test_upload_audio_file(client, sample_audio_file):
    """Test uploading an audio file."""
    with open(sample_audio_file, "rb") as f:
        response = client.post(
            "/upload",
            files={"file": ("test.wav", f, "audio/wav")}
        )

    assert response.status_code == 200
    data = response.json()
    assert "job_id" in data
    assert "audio_file_id" in data
    assert data["status"] == "queued"


@pytest.mark.unit
def test_upload_invalid_file_type(client):
    """Test uploading invalid file type."""
    # Create a fake text file
    file_content = b"This is not an audio file"
    files = {"file": ("test.txt", io.BytesIO(file_content), "text/plain")}

    response = client.post("/upload", files=files)

    assert response.status_code == 400
    assert "Invalid file type" in response.json()["detail"]


@pytest.mark.unit
def test_get_job_status(client, db_session):
    """Test getting job status."""
    # Create audio file and job
    audio_file = AudioFile(
        filename="test.mp3",
        filepath="/test.mp3",
        duration=100.0
    )
    db_session.add(audio_file)
    db_session.flush()

    job = ProcessingJob(
        audio_file_id=audio_file.id,
        status=ProcessingStatus.PROCESSING,
        progress=50,
        current_step="transcription"
    )
    db_session.add(job)
    db_session.commit()

    # Get job status
    response = client.get(f"/jobs/{job.id}")

    assert response.status_code == 200
    data = response.json()
    assert data["job_id"] == job.id
    assert data["status"] == "processing"
    assert data["progress"] == 50
    assert data["current_step"] == "transcription"


@pytest.mark.unit
def test_get_nonexistent_job(client):
    """Test getting non-existent job."""
    response = client.get("/jobs/nonexistent_id")
    assert response.status_code == 404


@pytest.mark.unit
def test_list_recordings(client, db_session):
    """Test listing recordings."""
    # Create some audio files
    for i in range(3):
        audio_file = AudioFile(
            filename=f"test_{i}.mp3",
            filepath=f"/test_{i}.mp3",
            duration=100.0 + i * 10
        )
        db_session.add(audio_file)

    db_session.commit()

    response = client.get("/recordings")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 3


@pytest.mark.unit
def test_list_speakers(client, db_session):
    """Test listing speakers."""
    # Create some speakers
    for i in range(5):
        speaker = Speaker(name=f"Speaker {i}")
        db_session.add(speaker)

    db_session.commit()

    response = client.get("/speakers")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 5
    assert data[0]["name"] == "Speaker 0"


@pytest.mark.unit
def test_get_speaker_details(client, db_session):
    """Test getting speaker details."""
    speaker = Speaker(
        name="John Doe",
        total_duration_seconds=500.0,
        file_count=3
    )
    db_session.add(speaker)
    db_session.commit()

    response = client.get(f"/speakers/{speaker.id}")

    assert response.status_code == 200
    data = response.json()
    assert data["speaker_id"] == speaker.id
    assert data["name"] == "John Doe"
    assert data["total_duration"] == 500.0
    assert data["file_count"] == 3


@pytest.mark.unit
def test_get_nonexistent_speaker(client):
    """Test getting non-existent speaker."""
    response = client.get("/speakers/nonexistent_id")
    assert response.status_code == 404


@pytest.mark.unit
def test_update_speaker(client, db_session):
    """Test updating speaker name."""
    speaker = Speaker(name="Original Name")
    db_session.add(speaker)
    db_session.commit()

    response = client.put(
        f"/speakers/{speaker.id}",
        json={"name": "Updated Name"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True

    # Verify update
    db_session.refresh(speaker)
    assert speaker.name == "Updated Name"


@pytest.mark.unit
def test_merge_speakers(client, db_session):
    """Test merging two speakers."""
    speaker1 = Speaker(name="Speaker 1")
    speaker2 = Speaker(name="Speaker 2")
    db_session.add_all([speaker1, speaker2])
    db_session.commit()

    response = client.post(
        "/speakers/merge",
        json={
            "source_speaker_id": speaker1.id,
            "target_speaker_id": speaker2.id
        }
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True


@pytest.mark.unit
def test_delete_speaker(client, db_session):
    """Test deleting a speaker."""
    speaker = Speaker(name="Test Speaker")
    db_session.add(speaker)
    db_session.commit()
    speaker_id = speaker.id

    response = client.delete(f"/speakers/{speaker_id}")

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True

    # Verify deletion
    deleted_speaker = db_session.query(Speaker).filter(
        Speaker.id == speaker_id
    ).first()
    assert deleted_speaker is None


@pytest.mark.unit
def test_upload_with_duplicate_filename(client, sample_audio_file, test_upload_dir):
    """Test uploading files with duplicate names."""
    # Upload first file
    with open(sample_audio_file, "rb") as f:
        response1 = client.post(
            "/upload",
            files={"file": ("test.wav", f, "audio/wav")}
        )

    assert response1.status_code == 200
    filename1 = response1.json()["filename"]

    # Upload again with same name
    with open(sample_audio_file, "rb") as f:
        response2 = client.post(
            "/upload",
            files={"file": ("test.wav", f, "audio/wav")}
        )

    assert response2.status_code == 200
    filename2 = response2.json()["filename"]

    # Filenames should be different (second one should have counter)
    assert filename1 != filename2
    assert "test" in filename2


@pytest.mark.unit
def test_get_recording_not_processed(client, db_session):
    """Test getting recording that hasn't been processed yet."""
    audio_file = AudioFile(
        filename="test.mp3",
        filepath="/test.mp3",
        duration=100.0,
        processing_status=ProcessingStatus.PROCESSING
    )
    db_session.add(audio_file)
    db_session.commit()

    response = client.get(f"/recordings/{audio_file.id}")

    assert response.status_code == 400
    assert "not yet processed" in response.json()["detail"]


@pytest.mark.unit
def test_pagination_speakers(client, db_session):
    """Test pagination for speakers list."""
    # Create 25 speakers
    for i in range(25):
        speaker = Speaker(name=f"Speaker {i:02d}")
        db_session.add(speaker)

    db_session.commit()

    # Get first page
    response1 = client.get("/speakers?limit=10&offset=0")
    assert response1.status_code == 200
    data1 = response1.json()
    assert len(data1) == 10

    # Get second page
    response2 = client.get("/speakers?limit=10&offset=10")
    assert response2.status_code == 200
    data2 = response2.json()
    assert len(data2) == 10

    # Verify different results
    assert data1[0]["speaker_id"] != data2[0]["speaker_id"]
