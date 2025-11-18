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
from services.gemini_audio_processor import GeminiAudioProcessor
from config import settings

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

        file_path = Path(audio_file.filepath)

        # Choose pipeline based on configuration
        pipeline_type = settings.AUDIO_PIPELINE.lower()
        logger.info(f"Using audio processing pipeline: {pipeline_type}")

        if pipeline_type == "gemini":
            # Use Gemini-only pipeline
            result = _process_with_gemini_pipeline(
                db, vector_store, job, audio_file, file_path
            )
        else:
            # Use traditional pipeline (pyannote + Whisper + LLM)
            result = _process_with_traditional_pipeline(
                db, vector_store, job, audio_file, file_path
            )

        return result

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


def _process_with_gemini_pipeline(
    db,
    vector_store,
    job: ProcessingJob,
    audio_file: AudioFile,
    file_path: Path
) -> dict:
    """Process audio using Gemini-only pipeline."""
    logger.info("=== Starting Gemini Pipeline ===")

    audio_file_id = audio_file.id
    speaker_manager = SpeakerManager(db, vector_store)

    # Step 1: Process entire audio with Gemini (0-70%)
    logger.info("Step 1: Processing audio with Gemini API")
    job.current_step = "gemini_processing"
    job.progress = 5
    db.commit()

    gemini_processor = GeminiAudioProcessor()
    gemini_result = gemini_processor.process_audio_file(file_path)

    logger.info(f"Gemini processing complete: {len(gemini_result['segments'])} segments, "
               f"{len(gemini_result['speakers'])} speakers")

    job.progress = 50
    db.commit()

    # Format Gemini results to match traditional pipeline format
    segments, synthetic_embeddings, speaker_names = \
        gemini_processor.format_for_traditional_pipeline(gemini_result)

    job.progress = 60
    db.commit()

    # Step 2: Speaker Identification (60-70%)
    logger.info("Step 2: Identifying speakers with synthetic embeddings")
    job.current_step = "speaker_identification"

    speaker_mapping = {}  # Maps Gemini speaker_id to database speaker_id
    new_speakers = []

    for gemini_speaker_id, embedding in synthetic_embeddings.items():
        # Try to match with existing speakers or create new
        speaker_id, is_new = speaker_manager.identify_or_create_speaker(
            embedding,
            audio_file_id,
            speaker_names.get(gemini_speaker_id, gemini_speaker_id)
        )
        speaker_mapping[gemini_speaker_id] = speaker_id

        if is_new:
            new_speakers.append(speaker_id)

    logger.info(f"Identified {len(speaker_mapping)} speakers, {len(new_speakers)} new")

    # Update speaker names with detected names from Gemini
    for gemini_speaker_id, db_speaker_id in speaker_mapping.items():
        if gemini_speaker_id in gemini_result['speakers']:
            speaker_info = gemini_result['speakers'][gemini_speaker_id]
            detected_name = speaker_info.get('detected_name')

            # If Gemini detected an actual name, update the speaker record
            if detected_name:
                speaker = speaker_manager.get_speaker(db_speaker_id)
                if speaker:
                    speaker.name = detected_name
                    logger.info(f"Updated speaker {db_speaker_id} name to: {detected_name}")

    db.commit()
    logger.info("Updated speaker names with detected names from Gemini")

    job.progress = 70
    db.commit()

    # Step 3: Save segments to database (70-80%)
    logger.info("Step 3: Saving segments to database")
    job.current_step = "saving_segments"

    for segment_data in segments:
        gemini_speaker_id = segment_data['speaker_id']
        db_speaker_id = speaker_mapping[gemini_speaker_id]

        segment = SpeakerSegment(
            audio_file_id=audio_file_id,
            speaker_id=db_speaker_id,
            start_time=segment_data['start'],
            end_time=segment_data['end'],
            duration=segment_data['duration'],
            confidence=segment_data.get('confidence', 0.8),
            transcription=segment_data.get('transcription', ''),
            embedding_id=f"{audio_file_id}_{segment_data['start']}"
        )
        db.add(segment)

    db.commit()
    logger.info("Saved segments to database")

    job.progress = 80
    db.commit()

    # Step 4: Save insights (80-95%)
    logger.info("Step 4: Saving insights from Gemini")
    job.current_step = "saving_insights"

    # Save conversation insights
    from database.models import ConversationInsight, SpeakerInsight, SpeakerAudioFile

    conv_insights = gemini_result['conversation_insights']
    conversation_insight = ConversationInsight(
        audio_file_id=audio_file_id,
        summary=conv_insights.get('summary'),
        sentiment_overall=conv_insights.get('sentiment_overall'),
        sentiment_score=conv_insights.get('sentiment_score'),
        key_topics=conv_insights.get('key_topics', []),
        action_items=conv_insights.get('action_items', []),
        meetings_reminders=conv_insights.get('meetings_reminders', [])
    )
    db.add(conversation_insight)
    db.commit()

    logger.info("Saved conversation insights")

    job.progress = 85
    db.commit()

    # Calculate speaker durations and save speaker insights
    speaker_durations = {}
    segment_counts = {}

    for segment_data in segments:
        gemini_speaker_id = segment_data['speaker_id']
        db_speaker_id = speaker_mapping[gemini_speaker_id]

        if db_speaker_id not in speaker_durations:
            speaker_durations[db_speaker_id] = 0
            segment_counts[db_speaker_id] = 0

        speaker_durations[db_speaker_id] += segment_data['duration']
        segment_counts[db_speaker_id] += 1

    # Update speaker statistics and save insights
    for db_speaker_id, duration in speaker_durations.items():
        # Update speaker stats
        speaker_manager.update_speaker_stats(db_speaker_id, audio_file_id, duration)

        # Create speaker-audio association
        association = speaker_manager.create_speaker_audio_association(
            db_speaker_id,
            audio_file_id,
            duration,
            segment_counts[db_speaker_id]
        )

        # Find Gemini speaker ID for this database speaker
        gemini_speaker_id = None
        for g_id, d_id in speaker_mapping.items():
            if d_id == db_speaker_id:
                gemini_speaker_id = g_id
                break

        if gemini_speaker_id and gemini_speaker_id in gemini_result['speaker_insights']:
            insights_data = gemini_result['speaker_insights'][gemini_speaker_id]

            speaker_insight = SpeakerInsight(
                speaker_audio_file_id=association.id,
                speaking_style=insights_data.get('speaking_style'),
                sentiment=insights_data.get('sentiment'),
                sentiment_score=insights_data.get('sentiment_score'),
                improvements=insights_data.get('improvements', []),
                word_count=insights_data.get('word_count', 0),
                filler_words_count=insights_data.get('filler_words_count', 0),
                speaking_pace=insights_data.get('speaking_pace', 0.0)
            )
            db.add(speaker_insight)

    db.commit()
    logger.info("Saved speaker insights")

    job.progress = 95
    db.commit()

    # Step 5: Finalize
    logger.info("Finalizing Gemini pipeline processing")
    job.current_step = "completed"
    job.progress = 100
    job.status = ProcessingStatus.COMPLETED
    job.completed_at = datetime.utcnow()
    job.result = {
        "pipeline": "gemini",
        "speakers_detected": len(speaker_mapping),
        "new_speakers": len(new_speakers),
        "segments_count": len(segments),
        "total_duration": audio_file.duration
    }

    audio_file.processing_status = ProcessingStatus.COMPLETED
    audio_file.processed_at = datetime.utcnow()

    db.commit()

    logger.info(f"=== Gemini Pipeline Complete for audio {audio_file_id} ===")

    return {
        "success": True,
        "audio_file_id": audio_file_id,
        "pipeline": "gemini",
        "speakers_detected": len(speaker_mapping),
        "new_speakers": new_speakers,
        "segments_count": len(segments)
    }


def _process_with_traditional_pipeline(
    db,
    vector_store,
    job: ProcessingJob,
    audio_file: AudioFile,
    file_path: Path
) -> dict:
    """Process audio using traditional pipeline (pyannote + Whisper + LLM)."""
    logger.info("=== Starting Traditional Pipeline ===")

    audio_file_id = audio_file.id

    # Initialize services
    audio_processor = AudioProcessor()
    diarization_service = SpeakerDiarizationService()
    transcription_service = TranscriptionService()
    speaker_manager = SpeakerManager(db, vector_store)
    insights_generator = InsightsGenerator(db)

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
        "pipeline": "traditional",
        "speakers_detected": len(speaker_mapping),
        "new_speakers": len(new_speakers),
        "segments_count": len(transcribed_segments),
        "total_duration": audio_file.duration
    }

    audio_file.processing_status = ProcessingStatus.COMPLETED
    audio_file.processed_at = datetime.utcnow()

    db.commit()

    logger.info(f"=== Traditional Pipeline Complete for audio {audio_file_id} ===")

    return {
        "success": True,
        "audio_file_id": audio_file_id,
        "pipeline": "traditional",
        "speakers_detected": len(speaker_mapping),
        "new_speakers": new_speakers,
        "segments_count": len(transcribed_segments)
    }
