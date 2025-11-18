import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/recording_model.dart';

class SpeakerRecordingInsightScreen extends StatefulWidget {
  final String audioFileId;
  final String speakerId;
  final String speakerName;
  final Color avatarColor;

  const SpeakerRecordingInsightScreen({
    super.key,
    required this.audioFileId,
    required this.speakerId,
    required this.speakerName,
    required this.avatarColor,
  });

  @override
  State<SpeakerRecordingInsightScreen> createState() =>
      _SpeakerRecordingInsightScreenState();
}

class _SpeakerRecordingInsightScreenState
    extends State<SpeakerRecordingInsightScreen> {
  final ApiService _apiService = ApiService();
  RecordingDetail? _recordingDetail;
  RecordingSpeaker? _speakerData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecordingInsights();
  }

  Future<void> _loadRecordingInsights() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🔍 [SpeakerRecordingInsight] Fetching recording: ${widget.audioFileId}');

      final recordingDetail = await _apiService.fetchRecordingDetails(widget.audioFileId);

      // Filter to get only this speaker's data
      final speakerData = recordingDetail.speakers.firstWhere(
        (speaker) => speaker.speakerId == widget.speakerId,
        orElse: () => throw Exception('Speaker not found in this recording'),
      );

      if (mounted) {
        setState(() {
          _recordingDetail = recordingDetail;
          _speakerData = speakerData;
          _isLoading = false;
        });

        print('✅ [SpeakerRecordingInsight] Loaded insights for ${widget.speakerName}');
      }
    } catch (e) {
      print('❌ [SpeakerRecordingInsight] Error: $e');

      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.speakerName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load insights',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadRecordingInsights,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_speakerData == null || _recordingDetail == null) {
      return const SizedBox.shrink();
    }

    final insights = _speakerData!.insights;
    final percentage = (_speakerData!.totalDuration / _recordingDetail!.duration * 100).round();

    return CustomScrollView(
      slivers: [
        // Top spacing for AppBar
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 16),
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Recording info subtitle
                Text(
                  _recordingDetail!.filename,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Large Circular Progress
                _buildCircularProgress(
                  context,
                  percentage: percentage,
                  label: 'Speaking Time',
                ),
                const SizedBox(height: 32),

                // Two Metric Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        icon: Icons.message,
                        label: 'Segments',
                        value: '${_speakerData!.segmentCount}',
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        icon: Icons.speed,
                        label: 'Speaking Pace',
                        value: '${insights.speakingPace.toStringAsFixed(0)} wpm',
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Insights Card
                _buildInsightsCard(context, insights),
                const SizedBox(height: 24),

                // Improvements Card
                if (insights.improvements.isNotEmpty) ...[
                  _buildImprovementsCard(context, insights),
                  const SizedBox(height: 24),
                ],

                // View Full Transcript Button
                _buildViewTranscriptButton(context),
                const SizedBox(height: 32),

                // Segments Section
                Text(
                  'Transcript',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Segments List
                ..._speakerData!.segments.map((segment) => _buildSegmentCard(context, segment)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircularProgress(
    BuildContext context, {
    required int percentage,
    required String label,
  }) {
    final progress = (percentage / 100).clamp(0.0, 1.0);

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 16,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          // Progress circle with gradient colors
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 16,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(widget.avatarColor),
            ),
          ),
          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.avatarColor,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(BuildContext context, SpeakerInsights insights) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sentimentEmoji = _getSentimentEmoji(insights.sentiment);
    final sentimentColor = _getSentimentColor(insights.sentiment);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                sentimentEmoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Speaking Insights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sentimentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  insights.sentiment.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: sentimentColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insights.speakingStyle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildImprovementsCard(BuildContext context, SpeakerInsights insights) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates,
                color: widget.avatarColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Suggestions for Improvement',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.improvements.map((improvement) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.avatarColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        improvement,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              height: 1.5,
                            ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildViewTranscriptButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Scroll to transcript section
            // TODO: Implement smooth scroll
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      color: widget.avatarColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'View Full Transcript',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                Icon(
                  Icons.arrow_forward,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentCard(BuildContext context, SpeakerSegment segment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = _formatTime(segment.start);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.avatarColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: widget.avatarColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${segment.duration.toStringAsFixed(0)}s',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              segment.transcription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final minutes = seconds ~/ 60;
    final secs = (seconds % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getSentimentEmoji(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return '😊';
      case 'negative':
        return '😟';
      case 'mixed':
        return '😐';
      default:
        return '😌';
    }
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      case 'mixed':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
