"""Pydantic models for API requests and responses."""
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime


# Upload responses
class UploadResponse(BaseModel):
    """Response for file upload."""
    job_id: str
    audio_file_id: str
    filename: str
    status: str
    message: str


# Job status
class JobStatusResponse(BaseModel):
    """Response for job status query."""
    job_id: str
    status: str
    progress: int
    current_step: Optional[str]
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    error_message: Optional[str]
    result: Optional[Dict[str, Any]]


# Speaker segment
class SpeakerSegmentResponse(BaseModel):
    """Speaker segment information."""
    start: float
    end: float
    duration: float
    transcription: str


# Speaker insights
class SpeakerInsightResponse(BaseModel):
    """Speaker-specific insights."""
    speaking_style: Optional[str]
    sentiment: Optional[str]
    sentiment_score: Optional[float]
    improvements: List[str]
    word_count: Optional[int]
    filler_words_count: Optional[int]
    speaking_pace: Optional[float]


# Speaker in recording
class SpeakerInRecordingResponse(BaseModel):
    """Speaker information within a recording."""
    speaker_id: str
    name: str
    is_new: bool
    total_duration: float
    segment_count: int
    segments: List[SpeakerSegmentResponse]
    insights: Optional[SpeakerInsightResponse]


# Action item
class ActionItemResponse(BaseModel):
    """Action item from conversation."""
    item: str
    assigned_to: Optional[str]
    mentioned_by: Optional[str]
    priority: Optional[str]


# Meeting/Reminder
class MeetingReminderResponse(BaseModel):
    """Meeting or reminder from conversation."""
    type: str
    description: str
    date_time: Optional[str]
    participants: Optional[List[str]]


# Conversation insights
class ConversationInsightResponse(BaseModel):
    """Conversation-level insights."""
    summary: Optional[str]
    sentiment: Optional[str]
    sentiment_score: Optional[float]
    key_topics: List[str]
    action_items: List[ActionItemResponse]
    meetings_reminders: List[MeetingReminderResponse]


# Full recording response
class RecordingResponse(BaseModel):
    """Complete recording information with all analysis."""
    audio_file_id: str
    filename: str
    duration: float
    uploaded_at: datetime
    processed_at: Optional[datetime]
    processing_status: str
    speakers_detected: int
    speakers: List[SpeakerInRecordingResponse]
    conversation_insights: Optional[ConversationInsightResponse]


# Speaker list item
class SpeakerListItem(BaseModel):
    """Speaker list item."""
    speaker_id: str
    name: str
    total_duration: float
    file_count: int
    created_at: datetime


# Speaker file info
class SpeakerFileInfo(BaseModel):
    """File information for speaker."""
    audio_file_id: str
    filename: str
    duration_in_file: float
    segment_count: int
    uploaded_at: str


# Speaker detail
class SpeakerDetailResponse(BaseModel):
    """Detailed speaker information."""
    speaker_id: str
    name: str
    total_duration: float
    file_count: int
    average_sentiment: Optional[float]
    created_at: datetime
    updated_at: datetime
    files: List[SpeakerFileInfo]


# Speaker update request
class SpeakerUpdateRequest(BaseModel):
    """Request to update speaker."""
    name: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


# Speaker merge request
class SpeakerMergeRequest(BaseModel):
    """Request to merge two speakers."""
    source_speaker_id: str
    target_speaker_id: str


# Generic success response
class SuccessResponse(BaseModel):
    """Generic success response."""
    success: bool
    message: str
    data: Optional[Dict[str, Any]] = None
