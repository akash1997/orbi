"""Main FastAPI application with speaker intelligence."""
import logging
from fastapi import FastAPI, File, UploadFile, HTTPException, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from pathlib import Path
from typing import List
import uuid

from config import settings
from database import init_db, get_db
from database.models import (
    AudioFile,
    ProcessingJob,
    ProcessingStatus,
    Speaker,
    SpeakerAudioFile,
    SpeakerSegment,
    ConversationInsight,
    SpeakerInsight
)
from database.vector_store import VectorStore
from services.speaker_manager import SpeakerManager
from tasks.process_audio import process_audio_file
from api.models import (
    UploadResponse,
    JobStatusResponse,
    RecordingResponse,
    SpeakerListItem,
    SpeakerDetailResponse,
    SpeakerUpdateRequest,
    SpeakerMergeRequest,
    SuccessResponse,
    SpeakerInRecordingResponse,
    SpeakerSegmentResponse,
    SpeakerInsightResponse,
    ConversationInsightResponse,
    ActionItemResponse,
    MeetingReminderResponse
)

# Configure logging
logging.basicConfig(
    level=logging.INFO if settings.DEBUG else logging.WARNING,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="AI-powered speaker intelligence API with automatic diarization, transcription, and conversation insights"
)

# Initialize database on startup
@app.on_event("startup")
async def startup_event():
    """Initialize database and create tables."""
    init_db()
    logger.info("Database initialized")


def is_audio_file(filename: str) -> bool:
    """Check if file has an allowed audio extension."""
    return Path(filename).suffix.lower() in settings.ALLOWED_EXTENSIONS


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "message": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "endpoints": {
            "upload": "/upload",
            "job_status": "/jobs/{job_id}",
            "recording": "/recordings/{audio_file_id}",
            "speakers": "/speakers"
        }
    }


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "version": settings.APP_VERSION}


@app.post("/upload", response_model=UploadResponse)
async def upload_audio(
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Upload audio file and start automatic processing.

    Automatically performs:
    - Speaker diarization (who spoke when)
    - Speech-to-text transcription
    - Speaker identification (match to existing or create new)
    - Conversation insights generation
    - Speaker-specific insights

    Returns job_id for tracking progress.
    """
    # Validate file type
    if not is_audio_file(file.filename):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed types: {', '.join(settings.ALLOWED_EXTENSIONS)}"
        )

    try:
        # Save file
        file_path = settings.UPLOAD_DIR / file.filename

        # Handle duplicate filenames
        counter = 1
        original_path = file_path
        while file_path.exists():
            stem = original_path.stem
            suffix = original_path.suffix
            file_path = settings.UPLOAD_DIR / f"{stem}_{counter}{suffix}"
            counter += 1

        # Save uploaded file
        with file_path.open("wb") as buffer:
            import shutil
            shutil.copyfileobj(file.file, buffer)

        # Get audio duration
        from utils.audio_utils import get_audio_duration
        duration = get_audio_duration(file_path)

        # Create database record
        audio_file = AudioFile(
            filename=file_path.name,
            filepath=str(file_path),
            duration=duration,
            format=file_path.suffix.lower(),
            processing_status=ProcessingStatus.QUEUED
        )
        db.add(audio_file)
        db.commit()
        db.refresh(audio_file)

        # Create processing job
        job = ProcessingJob(
            audio_file_id=audio_file.id,
            status=ProcessingStatus.QUEUED
        )
        db.add(job)
        db.commit()
        db.refresh(job)

        # Start async processing
        task = process_audio_file.delay(audio_file.id)
        job.celery_task_id = task.id
        db.commit()

        logger.info(f"Uploaded file {file_path.name}, started processing job {job.id}")

        return UploadResponse(
            job_id=job.id,
            audio_file_id=audio_file.id,
            filename=file_path.name,
            status="queued",
            message="File uploaded successfully. Processing started."
        )

    except Exception as e:
        logger.error(f"Error uploading file: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

    finally:
        file.file.close()


@app.get("/jobs/{job_id}", response_model=JobStatusResponse)
async def get_job_status(job_id: str, db: Session = Depends(get_db)):
    """
    Get processing job status.

    Poll this endpoint to track progress of audio processing.
    """
    job = db.query(ProcessingJob).filter(ProcessingJob.id == job_id).first()

    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    return JobStatusResponse(
        job_id=job.id,
        status=job.status.value,
        progress=job.progress,
        current_step=job.current_step,
        started_at=job.started_at,
        completed_at=job.completed_at,
        error_message=job.error_message,
        result=job.result
    )


@app.get("/recordings/{audio_file_id}", response_model=RecordingResponse)
async def get_recording(audio_file_id: str, db: Session = Depends(get_db)):
    """
    Get complete recording information with all analysis results.

    Returns:
    - Speaker timeline (who spoke when)
    - Transcriptions
    - Conversation insights
    - Speaker-specific insights
    """
    audio_file = db.query(AudioFile).filter(AudioFile.id == audio_file_id).first()

    if not audio_file:
        raise HTTPException(status_code=404, detail="Recording not found")

    if audio_file.processing_status != ProcessingStatus.COMPLETED:
        raise HTTPException(
            status_code=400,
            detail=f"Recording not yet processed. Status: {audio_file.processing_status.value}"
        )

    # Get all speakers in this recording
    speaker_assocs = db.query(SpeakerAudioFile).filter(
        SpeakerAudioFile.audio_file_id == audio_file_id
    ).all()

    speakers_response = []

    for assoc in speaker_assocs:
        # Get speaker
        speaker = db.query(Speaker).filter(Speaker.id == assoc.speaker_id).first()

        # Get segments
        segments = db.query(SpeakerSegment).filter(
            SpeakerSegment.audio_file_id == audio_file_id,
            SpeakerSegment.speaker_id == assoc.speaker_id
        ).order_by(SpeakerSegment.start_time).all()

        segments_response = [
            SpeakerSegmentResponse(
                start=seg.start_time,
                end=seg.end_time,
                duration=seg.duration,
                transcription=seg.transcription or ""
            )
            for seg in segments
        ]

        # Get insights
        insight = db.query(SpeakerInsight).filter(
            SpeakerInsight.speaker_audio_file_id == assoc.id
        ).first()

        insight_response = None
        if insight:
            insight_response = SpeakerInsightResponse(
                speaking_style=insight.speaking_style,
                sentiment=insight.sentiment,
                sentiment_score=insight.sentiment_score,
                improvements=insight.improvements or [],
                word_count=insight.word_count,
                filler_words_count=insight.filler_words_count,
                speaking_pace=insight.speaking_pace
            )

        # Check if this is a new speaker (created during this processing)
        is_new = len(db.query(SpeakerAudioFile).filter(
            SpeakerAudioFile.speaker_id == assoc.speaker_id
        ).all()) == 1

        speakers_response.append(
            SpeakerInRecordingResponse(
                speaker_id=speaker.id,
                name=speaker.name,
                is_new=is_new,
                total_duration=assoc.total_speech_duration,
                segment_count=assoc.segment_count,
                segments=segments_response,
                insights=insight_response
            )
        )

    # Get conversation insights
    conv_insight = db.query(ConversationInsight).filter(
        ConversationInsight.audio_file_id == audio_file_id
    ).first()

    conv_insight_response = None
    if conv_insight:
        action_items = [
            ActionItemResponse(**item) for item in (conv_insight.action_items or [])
        ]
        meetings = [
            MeetingReminderResponse(**meeting) for meeting in (conv_insight.meetings_reminders or [])
        ]

        conv_insight_response = ConversationInsightResponse(
            summary=conv_insight.summary,
            sentiment=conv_insight.sentiment_overall,
            sentiment_score=conv_insight.sentiment_score,
            key_topics=conv_insight.key_topics or [],
            action_items=action_items,
            meetings_reminders=meetings
        )

    return RecordingResponse(
        audio_file_id=audio_file.id,
        filename=audio_file.filename,
        duration=audio_file.duration,
        uploaded_at=audio_file.uploaded_at,
        processed_at=audio_file.processed_at,
        processing_status=audio_file.processing_status.value,
        speakers_detected=len(speakers_response),
        speakers=speakers_response,
        conversation_insights=conv_insight_response
    )


@app.get("/recordings", response_model=List[dict])
async def list_recordings(
    limit: int = 50,
    offset: int = 0,
    db: Session = Depends(get_db)
):
    """List all recordings."""
    recordings = db.query(AudioFile).offset(offset).limit(limit).all()

    return [
        {
            "audio_file_id": rec.id,
            "filename": rec.filename,
            "duration": rec.duration,
            "uploaded_at": rec.uploaded_at.isoformat(),
            "processing_status": rec.processing_status.value,
            "processed_at": rec.processed_at.isoformat() if rec.processed_at else None
        }
        for rec in recordings
    ]


@app.get("/speakers", response_model=List[SpeakerListItem])
async def list_speakers(
    limit: int = 100,
    offset: int = 0,
    db: Session = Depends(get_db)
):
    """List all speakers."""
    speakers = db.query(Speaker).offset(offset).limit(limit).all()

    return [
        SpeakerListItem(
            speaker_id=speaker.id,
            name=speaker.name,
            total_duration=speaker.total_duration_seconds,
            file_count=speaker.file_count,
            created_at=speaker.created_at
        )
        for speaker in speakers
    ]


@app.get("/speakers/{speaker_id}", response_model=SpeakerDetailResponse)
async def get_speaker(speaker_id: str, db: Session = Depends(get_db)):
    """Get detailed speaker information."""
    speaker = db.query(Speaker).filter(Speaker.id == speaker_id).first()

    if not speaker:
        raise HTTPException(status_code=404, detail="Speaker not found")

    # Get speaker manager
    speaker_manager = SpeakerManager(db)
    files = speaker_manager.get_speaker_files(speaker_id)

    return SpeakerDetailResponse(
        speaker_id=speaker.id,
        name=speaker.name,
        total_duration=speaker.total_duration_seconds,
        file_count=speaker.file_count,
        average_sentiment=speaker.average_sentiment,
        created_at=speaker.created_at,
        updated_at=speaker.updated_at,
        files=files
    )


@app.put("/speakers/{speaker_id}", response_model=SuccessResponse)
async def update_speaker(
    speaker_id: str,
    request: SpeakerUpdateRequest,
    db: Session = Depends(get_db)
):
    """Update speaker information (e.g., set a name)."""
    speaker_manager = SpeakerManager(db)
    speaker = speaker_manager.update_speaker(
        speaker_id,
        name=request.name,
        metadata=request.metadata
    )

    if not speaker:
        raise HTTPException(status_code=404, detail="Speaker not found")

    return SuccessResponse(
        success=True,
        message=f"Speaker {speaker_id} updated successfully",
        data={"speaker_id": speaker.id, "name": speaker.name}
    )


@app.post("/speakers/merge", response_model=SuccessResponse)
async def merge_speakers(
    request: SpeakerMergeRequest,
    db: Session = Depends(get_db)
):
    """Merge two speakers (useful for duplicate detection)."""
    speaker_manager = SpeakerManager(db)
    success = speaker_manager.merge_speakers(
        request.source_speaker_id,
        request.target_speaker_id
    )

    if not success:
        raise HTTPException(status_code=400, detail="Failed to merge speakers")

    return SuccessResponse(
        success=True,
        message=f"Successfully merged {request.source_speaker_id} into {request.target_speaker_id}"
    )


@app.delete("/speakers/{speaker_id}", response_model=SuccessResponse)
async def delete_speaker(speaker_id: str, db: Session = Depends(get_db)):
    """Delete a speaker and all associated data."""
    speaker_manager = SpeakerManager(db)
    success = speaker_manager.delete_speaker(speaker_id)

    if not success:
        raise HTTPException(status_code=404, detail="Speaker not found")

    return SuccessResponse(
        success=True,
        message=f"Speaker {speaker_id} deleted successfully"
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
