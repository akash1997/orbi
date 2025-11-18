class JobStatus {
  final String jobId;
  final String status;
  final int progress;
  final String? currentStep;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final Map<String, dynamic>? result;

  JobStatus({
    required this.jobId,
    required this.status,
    required this.progress,
    this.currentStep,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.result,
  });

  factory JobStatus.fromJson(Map<String, dynamic> json) {
    return JobStatus(
      jobId: json['job_id'] as String,
      status: json['status'] as String,
      progress: json['progress'] as int,
      currentStep: json['current_step'] as String?,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      errorMessage: json['error_message'] as String?,
      result: json['result'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'status': status,
      'progress': progress,
      'current_step': currentStep,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'error_message': errorMessage,
      'result': result,
    };
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing' || status == 'queued';
}
