import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../providers/config_provider.dart';
import '../../services/api_service.dart';
import '../../models/job_status.dart';

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  List<FileSystemEntity> _audioFiles = [];
  bool _isLoading = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ApiService _apiService = ApiService();
  String? _expandedFilePath;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Track upload job status for each file
  final Map<String, String> _fileJobIds = {}; // filePath -> jobId
  final Map<String, JobStatus?> _jobStatuses = {}; // filePath -> JobStatus
  final Map<String, bool> _uploadingFiles = {}; // filePath -> isUploading

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final config = ref.read(configProvider).value;
      if (config != null && config.monitoredFolderPath.isNotEmpty) {
        final directory = Directory(config.monitoredFolderPath);

        if (await directory.exists()) {
          // List all files in the directory
          final entities = directory.listSync();

          // Filter for audio files
          final audioFiles = entities.where((entity) {
            if (entity is File) {
              final fileName = entity.uri.pathSegments.last;

              // Ignore hidden files (starting with .)
              if (fileName.startsWith('.')) return false;

              // Ignore Android deleted/trashed files
              if (fileName.startsWith('~') || fileName.endsWith('~')) return false;

              // Ignore Android temporary/cache files
              if (fileName.contains('.tmp') || fileName.contains('.temp')) return false;

              // Ignore Android trashed files pattern
              if (fileName.contains('.trashed-')) return false;

              // Check for valid audio extensions
              final extension = entity.path.toLowerCase().split('.').last;
              return ['mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg'].contains(extension);
            }
            return false;
          }).toList();

          // Sort by modification date (newest first)
          audioFiles.sort((a, b) {
            final aStat = (a as File).statSync();
            final bStat = (b as File).statSync();
            return bStat.modified.compareTo(aStat.modified);
          });

          setState(() {
            _audioFiles = audioFiles;
            _isLoading = false;
          });
        } else {
          setState(() {
            _audioFiles = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _audioFiles = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ [RecordingsScreen] Error loading recordings: $e');
      setState(() {
        _audioFiles = [];
        _isLoading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Future<void> _playAudio(String filePath) async {
    try {
      if (_expandedFilePath == filePath && _isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_expandedFilePath != filePath) {
          await _audioPlayer.stop();
          setState(() {
            _expandedFilePath = filePath;
            _position = Duration.zero;
          });
        }
        await _audioPlayer.play(DeviceFileSource(filePath));
      }
    } catch (e) {
      print('❌ [RecordingsScreen] Error playing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void _toggleCardExpansion(String filePath) {
    setState(() {
      if (_expandedFilePath == filePath) {
        _expandedFilePath = null;
        _audioPlayer.stop();
      } else {
        _expandedFilePath = filePath;
        _playAudio(filePath);
      }
    });
  }

  /// Upload audio file to backend
  Future<void> _uploadAudioFile(File file) async {
    final fileName = file.uri.pathSegments.last;
    final filePath = file.path;

    setState(() {
      _uploadingFiles[filePath] = true;
    });

    try {
      print('📤 [RecordingsScreen] Uploading file: $fileName');

      // Show uploading toast
      Fluttertoast.showToast(
        msg: "Uploading $fileName...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.blue,
        textColor: Colors.white,
      );

      // Upload file
      final uploadResponse = await _apiService.uploadAudioFile(file);

      print('✅ [RecordingsScreen] Upload successful! Job ID: ${uploadResponse.jobId}');

      // Store job ID and fetch initial status
      if (mounted) {
        setState(() {
          _uploadingFiles[filePath] = false;
          _fileJobIds[filePath] = uploadResponse.jobId;
        });

        // Fetch initial job status
        await _refreshJobStatus(filePath);

        Fluttertoast.showToast(
          msg: "Upload successful! Processing...",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('❌ [RecordingsScreen] Upload error: $e');

      if (mounted) {
        setState(() {
          _uploadingFiles[filePath] = false;
        });

        Fluttertoast.showToast(
          msg: "Failed to upload $fileName",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  /// Refresh job status for a file
  Future<void> _refreshJobStatus(String filePath) async {
    final jobId = _fileJobIds[filePath];
    if (jobId == null) return;

    try {
      print('🔄 [RecordingsScreen] Refreshing job status for: $jobId');

      final jobStatus = await _apiService.getJobStatus(jobId);

      if (mounted) {
        setState(() {
          _jobStatuses[filePath] = jobStatus;
        });

        print('✅ [RecordingsScreen] Job status updated: ${jobStatus.status} (${jobStatus.progress}%)');
      }
    } catch (e) {
      print('❌ [RecordingsScreen] Error fetching job status: $e');

      if (mounted) {
        Fluttertoast.showToast(
          msg: "Failed to fetch job status",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Recordings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecordings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _audioFiles.isEmpty
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: _loadRecordings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _audioFiles.length,
                    itemBuilder: (context, index) {
                      final file = _audioFiles[index] as File;
                      return _buildRecordingCard(context, file, isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audio_file_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No recordings found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start monitoring a folder to see recordings',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(
    BuildContext context,
    File file,
    bool isDark,
  ) {
    final fileName = file.uri.pathSegments.last;
    final fileStat = file.statSync();
    final fileSize = _formatFileSize(fileStat.size);
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final modifiedDate = fileStat.modified;
    final isExpanded = _expandedFilePath == file.path;
    final isCurrentlyPlaying = isExpanded && _isPlaying;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _toggleCardExpansion(file.path),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.audio_file,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          file.path,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                fontSize: 10,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      _showRecordingOptions(context, file);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Recording details
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDetailChip(
                    context,
                    Icons.storage,
                    fileSize,
                  ),
                  _buildDetailChip(
                    context,
                    Icons.calendar_today,
                    dateFormatter.format(modifiedDate),
                  ),
                ],
              ),
              // Upload progress section
              if (_uploadingFiles[file.path] == true || _jobStatuses[file.path] != null) ...[
                const SizedBox(height: 12),
                _buildUploadProgressSection(context, file),
              ],
              // Audio player (expanded)
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                // Play/Pause button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        isCurrentlyPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        size: 48,
                      ),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () => _playAudio(file.path),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                      ),
                      child: Slider(
                        value: _position.inSeconds.toDouble(),
                        max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                        onChanged: (value) {
                          _seekTo(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProgressSection(BuildContext context, File file) {
    final filePath = file.path;
    final isUploading = _uploadingFiles[filePath] == true;
    final jobStatus = _jobStatuses[filePath];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getProgressBackgroundColor(context, isUploading, jobStatus),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getProgressBorderColor(isUploading, jobStatus),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildProgressIcon(isUploading, jobStatus),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getProgressText(isUploading, jobStatus),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (jobStatus != null && !jobStatus.isCompleted && !jobStatus.isFailed)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () => _refreshJobStatus(filePath),
                  tooltip: 'Refresh status',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (jobStatus != null && (jobStatus.isCompleted || jobStatus.isFailed))
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _jobStatuses.remove(filePath);
                      _fileJobIds.remove(filePath);
                    });
                  },
                  tooltip: 'Dismiss',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (jobStatus != null) ...[
            if (jobStatus.currentStep != null) ...[
              const SizedBox(height: 4),
              Text(
                jobStatus.currentStep!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
              ),
            ],
            if (jobStatus.isProcessing) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: jobStatus.progress / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(jobStatus.progress)),
              ),
              const SizedBox(height: 4),
              Text(
                '${jobStatus.progress}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
              ),
            ],
            if (jobStatus.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                jobStatus.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Colors.red,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildProgressIcon(bool isUploading, JobStatus? jobStatus) {
    if (isUploading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (jobStatus != null) {
      if (jobStatus.isCompleted) {
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      } else if (jobStatus.isFailed) {
        return const Icon(Icons.error, color: Colors.red, size: 20);
      } else {
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
    }

    return const Icon(Icons.cloud_upload, size: 20);
  }

  String _getProgressText(bool isUploading, JobStatus? jobStatus) {
    if (isUploading) {
      return 'Uploading...';
    }

    if (jobStatus != null) {
      if (jobStatus.isCompleted) {
        return 'Processing completed!';
      } else if (jobStatus.isFailed) {
        return 'Processing failed';
      } else {
        return 'Processing audio file...';
      }
    }

    return 'Ready to upload';
  }

  Color _getProgressBackgroundColor(BuildContext context, bool isUploading, JobStatus? jobStatus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (jobStatus != null) {
      if (jobStatus.isCompleted) {
        return isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50]!;
      } else if (jobStatus.isFailed) {
        return isDark ? Colors.red[900]!.withOpacity(0.3) : Colors.red[50]!;
      } else {
        return isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50]!;
      }
    }

    return isDark ? Colors.grey[800]! : Colors.grey[100]!;
  }

  Color _getProgressBorderColor(bool isUploading, JobStatus? jobStatus) {
    if (jobStatus != null) {
      if (jobStatus.isCompleted) {
        return Colors.green;
      } else if (jobStatus.isFailed) {
        return Colors.red;
      } else {
        return Colors.blue;
      }
    }

    return Colors.grey;
  }

  Color _getProgressColor(int progress) {
    if (progress < 33) {
      return Colors.orange;
    } else if (progress < 66) {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }

  void _showRecordingOptions(BuildContext context, File file) {
    final fileName = file.uri.pathSegments.last;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  fileName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Play'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Playing $fileName')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('Upload to Server'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadAudioFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Show in Folder'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Path: ${file.path}')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Details'),
                onTap: () {
                  Navigator.pop(context);
                  _showFileDetails(context, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, file);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileDetails(BuildContext context, File file) {
    final fileName = file.uri.pathSegments.last;
    final fileStat = file.statSync();
    final fileSize = _formatFileSize(fileStat.size);
    final dateFormatter = DateFormat('MMM dd, yyyy hh:mm a');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', fileName),
            const SizedBox(height: 8),
            _buildDetailRow('Size', fileSize),
            const SizedBox(height: 8),
            _buildDetailRow('Modified', dateFormatter.format(fileStat.modified)),
            const SizedBox(height: 8),
            _buildDetailRow('Path', file.path),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, File file) {
    final fileName = file.uri.pathSegments.last;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text('Are you sure you want to delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await file.delete();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted: $fileName')),
                  );
                }
                await _loadRecordings();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting file: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
