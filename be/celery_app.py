"""Celery application configuration."""
from celery import Celery
from config import settings

# Create Celery app
celery_app = Celery(
    "orbi",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["tasks.process_audio"]
)

# Celery configuration
celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=3600,  # 1 hour max per task
    task_soft_time_limit=3300,  # 55 minutes soft limit
    worker_prefetch_multiplier=1,  # Process one task at a time
    worker_max_tasks_per_child=10,  # Restart worker after 10 tasks (prevent memory leaks)
)

# Task routes (optional - for task-specific queues)
# Using default 'celery' queue for all tasks
# celery_app.conf.task_routes = {
#     "tasks.process_audio.*": {"queue": "audio_processing"},
# }

if __name__ == "__main__":
    celery_app.start()
