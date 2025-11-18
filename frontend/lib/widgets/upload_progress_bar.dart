import 'package:flutter/material.dart';
import '../models/job_status.dart';

class UploadProgressBar extends StatelessWidget {
  final JobStatus jobStatus;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  const UploadProgressBar({
    super.key,
    required this.jobStatus,
    this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _getBackgroundColor(isDark),
          border: Border(
            top: BorderSide(
              color: _getBorderColor(),
              width: 2,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Status icon
              _buildStatusIcon(),
              const SizedBox(width: 12),

              // Progress info
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusText(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (jobStatus.currentStep != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        jobStatus.currentStep!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                      ),
                    ],
                    if (jobStatus.isProcessing) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: jobStatus.progress / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${jobStatus.progress}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ],
                ),
              ),

              // Retry and Dismiss buttons
              if (jobStatus.isFailed) ...[
                const SizedBox(width: 12),
                // Retry button
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: onRetry,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Retry',
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                // Dismiss button
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Dismiss',
                ),
              ],
              // Only dismiss button for completed
              if (jobStatus.isCompleted) ...[
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Dismiss',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (jobStatus.isCompleted) {
      return const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 32,
      );
    } else if (jobStatus.isFailed) {
      return const Icon(
        Icons.error,
        color: Colors.red,
        size: 32,
      );
    } else {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      );
    }
  }

  String _getStatusText() {
    if (jobStatus.isCompleted) {
      return 'Processing completed!';
    } else if (jobStatus.isFailed) {
      return 'Processing failed: ${jobStatus.errorMessage ?? "Unknown error"}';
    } else {
      return 'Processing audio file...';
    }
  }

  Color _getBackgroundColor(bool isDark) {
    if (jobStatus.isCompleted) {
      return isDark ? Colors.green[900]! : Colors.green[50]!;
    } else if (jobStatus.isFailed) {
      return isDark ? Colors.red[900]! : Colors.red[50]!;
    } else {
      return isDark ? Colors.grey[900]! : Colors.white;
    }
  }

  Color _getBorderColor() {
    if (jobStatus.isCompleted) {
      return Colors.green;
    } else if (jobStatus.isFailed) {
      return Colors.red;
    } else {
      return Colors.blue;
    }
  }

  Color _getProgressColor() {
    if (jobStatus.progress < 33) {
      return Colors.orange;
    } else if (jobStatus.progress < 66) {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }
}
