import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/speaker_profile_provider.dart';
import '../../services/speaker_profile_service.dart';
import '../../services/api_service.dart';
import '../../models/speaker_model.dart';

class InsightDetailScreen extends ConsumerStatefulWidget {
  final String speakerId;
  final String userName;
  final String duration;
  final int fileCount;
  final Color avatarColor;
  final String? initialAvatarImagePath;

  const InsightDetailScreen({
    super.key,
    required this.speakerId,
    required this.userName,
    required this.duration,
    required this.fileCount,
    required this.avatarColor,
    this.initialAvatarImagePath,
  });

  @override
  ConsumerState<InsightDetailScreen> createState() => _InsightDetailScreenState();
}

class _InsightDetailScreenState extends ConsumerState<InsightDetailScreen> {
  late String _currentName;
  String? _avatarImagePath;
  final _nameController = TextEditingController();
  bool _showEditButtons = false;
  final ApiService _apiService = ApiService();

  // API data
  Speaker? _speakerData;
  bool _isLoadingData = true;
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    _currentName = widget.userName;
    _avatarImagePath = widget.initialAvatarImagePath;
    _nameController.text = _currentName;
    _loadProfile();
    _fetchSpeakerData();

    // Show edit buttons after Hero animation completes (typically 300ms)
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _showEditButtons = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _speakerId => widget.speakerId;

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    // Get first letter of first name and first letter of last name
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  Future<void> _fetchSpeakerData() async {
    setState(() {
      _isLoadingData = true;
      _loadingError = null;
    });

    try {
      print('🔍 [InsightDetailScreen] Fetching speaker data for: ${widget.speakerId}');

      final speaker = await _apiService.getSpeaker(widget.speakerId);

      if (mounted) {
        setState(() {
          _speakerData = speaker;
          _isLoadingData = false;
        });

        print('✅ [InsightDetailScreen] Speaker data loaded: ${speaker.name}');
      }
    } catch (e) {
      print('❌ [InsightDetailScreen] Error fetching speaker data: $e');

      if (mounted) {
        setState(() {
          _loadingError = e.toString();
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _loadProfile() async {
    final service = ref.read(speakerProfileServiceProvider);
    final profile = await service.getProfile(_speakerId);

    if (profile != null) {
      setState(() {
        _currentName = profile.name;
        _avatarImagePath = profile.avatarImagePath;
        _nameController.text = _currentName;
      });
    } else {
      // Create initial profile
      final newProfile = SpeakerProfile(
        id: _speakerId,
        name: widget.userName,
      );
      await service.saveProfile(newProfile);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final imagePath = result.files.single.path!;
        final service = ref.read(speakerProfileServiceProvider);
        await service.updateSpeakerAvatar(_speakerId, imagePath);

        setState(() {
          _avatarImagePath = imagePath;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar updated successfully')),
          );
        }
      }
    } catch (e) {
      print('❌ [InsightDetailScreen] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating avatar: $e')),
        );
      }
    }
  }

  Future<void> _editName() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Speaker Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Speaker Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty && newName != _currentName) {
                final service = ref.read(speakerProfileServiceProvider);
                await service.updateSpeakerName(_speakerId, newName);

                setState(() {
                  _currentName = newName;
                });

                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name updated successfully')),
                  );
                }
              } else {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Insight Details',
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
      body: CustomScrollView(
        slivers: [
          // Avatar and Name Section
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                bottom: 32.0,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.avatarColor.withOpacity(0.1),
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Hero Avatar with Edit Button
                  Stack(
                    children: [
                      Hero(
                        tag: 'avatar_${widget.userName}',
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _avatarImagePath == null
                                  ? LinearGradient(
                                      colors: [
                                        Color.lerp(widget.avatarColor, Colors.white, 0.3)!,
                                        widget.avatarColor,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              image: _avatarImagePath != null
                                  ? DecorationImage(
                                      image: FileImage(File(_avatarImagePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.avatarColor.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _avatarImagePath == null
                                ? Center(
                                    child: Text(
                                      _getInitials(_currentName),
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      if (_showEditButtons)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: AnimatedOpacity(
                            opacity: _showEditButtons ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Material(
                              color: Theme.of(context).colorScheme.primary,
                              shape: const CircleBorder(),
                              elevation: 4,
                              child: InkWell(
                                onTap: _pickImage,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Speaker Name with Edit Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      if (_showEditButtons) ...[
                        const SizedBox(width: 8),
                        AnimatedOpacity(
                          opacity: _showEditButtons ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: IconButton(
                            onPressed: _editName,
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: 'Edit name',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _isLoadingData
                  ? _buildShimmerContent(context)
                  : _loadingError != null
                      ? _buildErrorContent(context)
                      : _buildContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[700]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[500]! : Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shimmer cards
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            height: 24,
            width: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          'Failed to load speaker data',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          _loadingError!,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _fetchSpeakerData,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final speaker = _speakerData;
    if (speaker == null) return const SizedBox.shrink();

    // Calculate total segments across all files
    final totalSegments = speaker.files.fold<int>(
      0,
      (sum, file) => sum + file.segmentCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Two Metric Cards in a Row - File Count and Total Duration
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                icon: Icons.audio_file,
                label: 'Audio Files',
                value: '${speaker.fileCount}',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                context,
                icon: Icons.access_time,
                label: 'Total Duration',
                value: speaker.getFormattedDuration(),
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Files Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recordings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (totalSegments > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalSegments segments',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // File Timeline
        if (speaker.files.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.audio_file_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recordings yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            ),
          )
        else
          ...speaker.files.map((file) => _buildFileTimelineItem(context, file)),
      ],
    );
  }

  String _formatAvgDuration(double seconds) {
    final minutes = seconds ~/ 60;
    final secs = (seconds % 60).round();
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  Widget _buildCircularProgress(
    BuildContext context, {
    required int value,
    required int maxValue,
    required String label,
    required Color color,
  }) {
    final percentage = (value / maxValue * 100).clamp(0, 100).toInt();
    final progress = (value / maxValue).clamp(0.0, 1.0);

    return Container(
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
          // Progress circle
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 16,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(color),
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
                      color: color,
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
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(
    BuildContext context,
    Speaker speaker,
    int totalSegments,
    int avgSegments,
  ) {
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
              Text(
                '💡 ',
                style: TextStyle(fontSize: 24),
              ),
              Expanded(
                child: Text(
                  'Speaker Insights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This speaker has contributed ${speaker.fileCount} audio files with a total duration of ${speaker.getFormattedDuration()}. '
            'On average, each file contains $avgSegments speaking segments, totaling $totalSegments segments across all recordings.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTimelineItem(BuildContext context, SpeakerFile file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeAgo = _getTimeAgo(file.uploadedAt);
    final formattedDuration = _formatDuration(file.durationInFile);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToRecordingInsights(file.audioFileId),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.audio_file,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.filename,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDuration,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '• $timeAgo',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${file.segmentCount}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.purple,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'segments',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
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

  String _formatDuration(double seconds) {
    final minutes = seconds ~/ 60;
    final secs = (seconds % 60).round();
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  void _navigateToRecordingInsights(String audioFileId) {
    // TODO: Implement navigation to recording insights when the feature is ready
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recording: $audioFileId'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
