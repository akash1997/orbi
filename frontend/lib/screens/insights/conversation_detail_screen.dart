import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/recording_model.dart';
import 'speaker_recording_insight_screen.dart';

class ConversationDetailScreen extends StatefulWidget {
  final String audioFileId;
  final String filename;

  const ConversationDetailScreen({
    super.key,
    required this.audioFileId,
    required this.filename,
  });

  @override
  State<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  final ApiService _apiService = ApiService();
  RecordingDetail? _recordingDetail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecordingDetails();
  }

  Future<void> _loadRecordingDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🔍 [ConversationDetail] Fetching recording: ${widget.audioFileId}');

      final recordingDetail = await _apiService.fetchRecordingDetails(widget.audioFileId);

      if (mounted) {
        setState(() {
          _recordingDetail = recordingDetail;
          _isLoading = false;
        });

        print('✅ [ConversationDetail] Loaded recording details');
      }
    } catch (e) {
      print('❌ [ConversationDetail] Error: $e');

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
      appBar: AppBar(
        title: Text(
          widget.filename,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
              'Failed to load conversation',
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
              onPressed: _loadRecordingDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_recordingDetail == null) {
      return const SizedBox.shrink();
    }

    final insights = _recordingDetail!.conversationInsights;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          _buildSummaryCard(context, insights.summary),
          const SizedBox(height: 24),

          // Key Topics
          if (insights.keyTopics.isNotEmpty) ...[
            _buildKeyTopics(context, insights.keyTopics),
            const SizedBox(height: 24),
          ],

          // Action Items
          if (insights.actionItems.isNotEmpty) ...[
            _buildActionItems(context, insights.actionItems),
            const SizedBox(height: 24),
          ],

          // Speakers Section
          Text(
            'Speakers (${_recordingDetail!.speakersDetected})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ..._recordingDetail!.speakers.map((speaker) => _buildSpeakerCard(context, speaker)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String summary) {
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
                Icons.summarize,
                color: Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyTopics(BuildContext context, List<String> topics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Topics',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: topics.map((topic) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                topic,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.purple,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionItems(BuildContext context, List<ActionItem> actionItems) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Action Items',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...actionItems.map((item) {
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
                  Text(
                    item.item,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (item.assignedTo != null) ...[
                        Icon(Icons.person, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          item.assignedTo!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(item.priority).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.priority.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _getPriorityColor(item.priority),
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSpeakerCard(BuildContext context, RecordingSpeaker speaker) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarColor = _getAvatarColor(speaker.speakerId.hashCode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToSpeakerInsights(speaker, avatarColor),
          borderRadius: BorderRadius.circular(12),
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
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: avatarColor,
                  radius: 24,
                  child: Text(
                    speaker.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        speaker.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${speaker.segmentCount} segments • ${_formatDuration(speaker.totalDuration)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getAvatarColor(int hash) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).round();
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  void _navigateToSpeakerInsights(RecordingSpeaker speaker, Color avatarColor) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpeakerRecordingInsightScreen(
          audioFileId: widget.audioFileId,
          speakerId: speaker.speakerId,
          speakerName: speaker.name,
          avatarColor: avatarColor,
        ),
      ),
    );
  }
}
