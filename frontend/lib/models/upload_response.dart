class UploadResponse {
  final String jobId;
  final String audioFileId;
  final String filename;
  final String status;
  final String message;

  UploadResponse({
    required this.jobId,
    required this.audioFileId,
    required this.filename,
    required this.status,
    required this.message,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      jobId: json['job_id'] as String,
      audioFileId: json['audio_file_id'] as String,
      filename: json['filename'] as String,
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'audio_file_id': audioFileId,
      'filename': filename,
      'status': status,
      'message': message,
    };
  }
}
