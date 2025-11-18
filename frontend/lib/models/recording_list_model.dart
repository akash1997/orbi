/// Model for recording list item from /recordings endpoint
class RecordingListItem {
  final String audioFileId;
  final String filename;
  final double duration;
  final DateTime uploadedAt;
  final DateTime? processedAt;
  final String processingStatus;

  RecordingListItem({
    required this.audioFileId,
    required this.filename,
    required this.duration,
    required this.uploadedAt,
    this.processedAt,
    required this.processingStatus,
  });

  factory RecordingListItem.fromJson(Map<String, dynamic> json) {
    return RecordingListItem(
      audioFileId: json['audio_file_id'] as String,
      filename: json['filename'] as String,
      duration: (json['duration'] as num).toDouble(),
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
      processingStatus: json['processing_status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audio_file_id': audioFileId,
      'filename': filename,
      'duration': duration,
      'uploaded_at': uploadedAt.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'processing_status': processingStatus,
    };
  }

  bool get isCompleted => processingStatus.toLowerCase() == 'completed';
  bool get isFailed => processingStatus.toLowerCase() == 'failed';
  bool get isProcessing => processingStatus.toLowerCase() == 'processing' || processingStatus.toLowerCase() == 'queued';
}
