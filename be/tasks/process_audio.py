"""Main Celery task for processing audio files."""
import logging
from datetime import datetime
from pathlib import Path
from celery_app import celery_app
from database.session import SessionLocal
from database.models import (
    AudioFile,
    ProcessingJob,
    ProcessingStatus,
    SpeakerSegment,
    Speaker
)
from database.vector_store import VectorStore
from services.audio_processor import AudioProcessor
from services.diarization import SpeakerDiarizationService
from services.transcription import TranscriptionService
from services.speaker_manager import SpeakerManager
from services.insights_generator import InsightsGenerator

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, name="tasks.process_audio.process_audio_file")
def process_audio_file(self, audio_file_id: str):
    """
    Process audio file: diarization, transcription, and insights generation.

    Args:
        audio_file_id: ID of audio file to process

    Returns:
        Dictionary with processing results
    """
    db = SessionLocal()
    vector_store = VectorStore()

    try:
        logger.info(f"Starting processing for audio file {audio_file_id}")

        # Get audio file from database
        audio_file = db.query(AudioFile).filter(AudioFile.id == audio_file_id).first()
        if not audio_file:
            raise ValueError(f"Audio file {audio_file_id} not found")

        # Get or create processing job
        job = db.query(ProcessingJob).filter(
            ProcessingJob.audio_file_id == audio_file_id
        ).first()

        if not job:
            job = ProcessingJob(
                audio_file_id=audio_file_id,
                celery_task_id=self.request.id
            )
            db.add(job)
            db.commit()
            db.refresh(job)

        # Update job status
        job.status = ProcessingStatus.PROCESSING
        job.started_at = datetime.utcnow()
        job.current_step = "initialization"
        job.progress = 0
        audio_file.processing_status = ProcessingStatus.PROCESSING
        db.commit()

        # Initialize services
        audio_processor = AudioProcessor()
        diarization_service = SpeakerDiarizationService()
        transcription_service = TranscriptionService()
        speaker_manager = SpeakerManager(db, vector_store)
        insights_generator = InsightsGenerator(db)

        file_path = Path(audio_file.filepath)

        # Step 1: Speaker Diarization (0-33%)
        logger.info("Step 1: Speaker diarization")
        job.current_step = "diarization"
        job.progress = 5
        db.commit()

        segments = diarization_service.diarize(file_path)
        logger.info(f"Found {len(segments)} segments with {len(set(s['speaker_label'] for s in segments))} speakers")

        # Extract embeddings for each segment
        job.progress = 15
        db.commit()

        embeddings = diarization_service.extract_embeddings_batch(file_path, segments)
        logger.info(f"Extracted {len(embeddings)} embeddings")

        # Identify or create speakers
        job.progress = 25
        db.commit()

        speaker_mapping = {}  # Maps temp speaker_label to actual speaker_id
        new_speakers = []

        for segment, embedding in zip(segments, embeddings):
            temp_label = segment['speaker_label']

            if temp_label not in speaker_mapping:
                # Identify or create speaker
                speaker_id, is_new = speaker_manager.identify_or_create_speaker(
                    embedding,
                    audio_file_id,
                    f"temp_{temp_label}"
                )
                speaker_mapping[temp_label] = speaker_id

                if is_new:
                    new_speakers.append(speaker_id)

        logger.info(f"Identified {len(speaker_mapping)} unique speakers, {len(new_speakers)} new")

        job.progress = 33
        db.commit()

        # Step 2: Transcription (33-66%)
        logger.info("Step 2: Transcription")
        job.current_step = "transcription"
        job.progress = 35
        db.commit()

        # Update segments with actual speaker IDs
        for segment in segments:
            segment['speaker_id'] = speaker_mapping[segment['speaker_label']]

        # Transcribe segments
        transcribed_segments = transcription_service.transcribe_segments(file_path, segments)
        logger.info(f"Transcribed {len(transcribed_segments)} segments")

        job.progress = 60
        db.commit()

        # Save segments to database
        for segment_data in transcribed_segments:
            segment = SpeakerSegment(
                audio_file_id=audio_file_id,
                speaker_id=segment_data['speaker_id'],
                start_time=segment_data['start'],
                end_time=segment_data['end'],
                duration=segment_data['duration'],
                confidence=segment_data.get('confidence', 1.0),
                transcription=segment_data.get('transcription', ''),
                embedding_id=f"{audio_file_id}_{segment_data['start']}"
            )
            db.add(segment)

        db.commit()
        logger.info("Saved segments to database")

        job.progress = 66
        db.commit()

        # Step 3: Insights Generation (66-100%)
        logger.info("Step 3: Generating insights")
        job.current_step = "insights"
        job.progress = 70
        db.commit()

        # Get speaker names for formatting
        speaker_names = {}
        for speaker_id in speaker_mapping.values():
            speaker = speaker_manager.get_speaker(speaker_id)
            if speaker:
                speaker_names[speaker_id] = speaker.name

        # Format full transcript
        full_transcript = transcription_service.format_transcript(
            transcribed_segments,
            include_timestamps=False,
            speaker_names=speaker_names
        )

        # Generate conversation insights
        conversation_insight = insights_generator.generate_conversation_insights(
            audio_file_id,
            full_transcript,
            speaker_names
        )
        logger.info("Generated conversation insights")

        job.progress = 80
        db.commit()

        # Get transcripts by speaker
        speaker_transcripts = transcription_service.get_transcript_by_speaker(transcribed_segments)

        # Calculate speaker durations
        speaker_durations = {}
        for speaker_id in speaker_mapping.values():
            duration = sum(
                s['duration'] for s in transcribed_segments
                if s.get('speaker_id') == speaker_id
            )
            speaker_durations[speaker_id] = duration

        # Update speaker statistics
        for speaker_id, duration in speaker_durations.items():
            speaker_manager.update_speaker_stats(speaker_id, audio_file_id, duration)

            # Create speaker-audio association
            segment_count = sum(
                1 for s in transcribed_segments
                if s.get('speaker_id') == speaker_id
            )
            speaker_manager.create_speaker_audio_association(
                speaker_id,
                audio_file_id,
                duration,
                segment_count
            )

        job.progress = 85
        db.commit()

        # Generate speaker insights
        speaker_insights = insights_generator.generate_all_speaker_insights(
            audio_file_id,
            speaker_transcripts,
            speaker_durations,
            speaker_names
        )
        logger.info(f"Generated insights for {len(speaker_insights)} speakers")

        job.progress = 95
        db.commit()

        # Step 4: Finalize
        logger.info("Finalizing processing")
        job.current_step = "completed"
        job.progress = 100
        job.status = ProcessingStatus.COMPLETED
        job.completed_at = datetime.utcnow()
        job.result = {
            "speakers_detected": len(speaker_mapping),
            "new_speakers": len(new_speakers),
            "segments_count": len(transcribed_segments),
            "total_duration": audio_file.duration
        }

        audio_file.processing_status = ProcessingStatus.COMPLETED
        audio_file.processed_at = datetime.utcnow()

        db.commit()

        logger.info(f"Successfully completed processing for audio file {audio_file_id}")

        return {
            "success": True,
            "audio_file_id": audio_file_id,
            "speakers_detected": len(speaker_mapping),
            "new_speakers": new_speakers,
            "segments_count": len(transcribed_segments)
        }

    except Exception as e:
        logger.error(f"Error processing audio file {audio_file_id}: {e}", exc_info=True)

        # Update job and audio file status
        if 'job' in locals():
            job.status = ProcessingStatus.FAILED
            job.error_message = str(e)
            job.completed_at = datetime.utcnow()

        if 'audio_file' in locals():
            audio_file.processing_status = ProcessingStatus.FAILED
            audio_file.error_message = str(e)

        db.commit()

        return {
            "success": False,
            "audio_file_id": audio_file_id,
            "error": str(e)
        }

    finally:
        db.close()
