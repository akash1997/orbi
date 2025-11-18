import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/config_provider.dart';
import '../../providers/file_monitor_provider.dart';
import '../../providers/speaker_profile_provider.dart';
import '../../widgets/drawer_3d.dart';
import '../../widgets/upload_progress_bar.dart';
import '../insights/insight_detail_screen.dart';
import '../recordings/recordings_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/api_service.dart';
import '../../models/speaker_model.dart';
import '../../models/job_status.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _drawerKey = GlobalKey<Drawer3DState>();
  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;
  final Map<String, String?> _avatarCache = {};
  final Map<String, String> _nameCache = {};
  final ApiService _apiService = ApiService();
  List<Speaker>? _speakers;
  bool _isLoadingSpeakers = false;
  String? _speakersError;

  // Upload and job tracking
  JobStatus? _currentJob;
  Timer? _jobPollingTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();

    // Initialize gradient animation
    _gradientController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _gradientAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _gradientController,
      curve: Curves.easeInOut,
    ));

    // Start monitoring when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMonitoring();
      _fetchSpeakers();
    });

    // Listen for new uploads from file monitor
    ref.listenManual(fileMonitorProvider, (previous, next) {
      if (next.lastJobId != null && next.lastJobId != previous?.lastJobId) {
        print('🆕 [HomeScreen] New job detected: ${next.lastJobId}');
        _startJobPolling(next.lastJobId!);

        // Show toast
        Fluttertoast.showToast(
          msg: "Processing ${next.lastUploadedFile ?? 'audio file'}...",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.blue,
          textColor: Colors.white,
        );
      }
    });
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _jobPollingTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    final config = ref.read(configProvider).value;
    if (config != null && config.isOnboardingComplete) {
      print('🚀 [HomeScreen] Starting monitoring on app launch');
      await ref
          .read(fileMonitorProvider.notifier)
          .startMonitoring(config.monitoredFolderPath);
    }
  }

  Future<void> _fetchSpeakers() async {
    setState(() {
      _isLoadingSpeakers = true;
      _speakersError = null;
    });

    try {
      print('🔍 [HomeScreen] Fetching speakers from API');
      final speakers = await _apiService.fetchSpeakers();

      print('✅ [HomeScreen] Received ${speakers.length} speakers');

      if (mounted) {
        setState(() {
          _speakers = speakers;
          _isLoadingSpeakers = false;
        });

        // Load avatar profiles for each speaker
        await _loadAvatarProfiles(speakers);
      }
    } catch (e) {
      print('❌ [HomeScreen] Error fetching speakers: $e');

      if (mounted) {
        setState(() {
          _speakersError = e.toString();
          _isLoadingSpeakers = false;
        });
      }
    }
  }

  Future<void> _loadAvatarProfiles(List<Speaker> speakers) async {
    final service = ref.read(speakerProfileServiceProvider);
    for (var speaker in speakers) {
      final speakerId = speaker.speakerId;
      final profile = await service.getProfile(speakerId);
      if (mounted) {
        setState(() {
          _avatarCache[speakerId] = profile?.avatarImagePath;
          // Cache the updated name from profile, or use speaker name
          _nameCache[speakerId] = profile?.name ?? speaker.name;
        });
      }
    }
  }

  Future<void> _refreshSpeakers() async {
    try {
      print('🔄 [HomeScreen] Refreshing speakers from API');
      final speakers = await _apiService.fetchSpeakers();

      print('✅ [HomeScreen] Refresh: Received ${speakers.length} speakers');

      if (mounted) {
        setState(() {
          _speakers = speakers;
          _speakersError = null;
        });

        // Load avatar profiles for each speaker
        await _loadAvatarProfiles(speakers);

        // Show success toast
        Fluttertoast.showToast(
          msg: "Refreshed! Found ${speakers.length} speaker${speakers.length == 1 ? '' : 's'}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      print('❌ [HomeScreen] Error refreshing speakers: $e');

      if (mounted) {
        setState(() {
          _speakersError = e.toString();
        });

        // Show error toast
        Fluttertoast.showToast(
          msg: "Failed to refresh speakers",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }
  }

  /// Upload an audio file automatically and start polling for job status
  Future<void> _uploadFile(File file, String filename) async {
    try {
      print('📤 [HomeScreen] Auto-uploading file: ${file.path}');

      // Show uploading toast
      Fluttertoast.showToast(
        msg: "Uploading $filename...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      // Upload file and get job ID
      final uploadResponse = await _apiService.uploadAudioFile(file);
      print('✅ [HomeScreen] Upload successful! Job ID: ${uploadResponse.jobId}');

      // Start polling for job status
      _startJobPolling(uploadResponse.jobId);

      // Show success toast
      Fluttertoast.showToast(
        msg: "Processing $filename...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      print('❌ [HomeScreen] Upload error: $e');
      Fluttertoast.showToast(
        msg: "Failed to upload $filename",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  /// Start polling job status every 2 seconds
  void _startJobPolling(String jobId) {
    // Cancel any existing timer
    _jobPollingTimer?.cancel();

    // Poll immediately
    _pollJobStatus(jobId);

    // Then poll every 2 seconds
    _jobPollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _pollJobStatus(jobId);
    });
  }

  /// Poll job status and update UI
  Future<void> _pollJobStatus(String jobId) async {
    try {
      final jobStatus = await _apiService.getJobStatus(jobId);

      if (mounted) {
        setState(() {
          _currentJob = jobStatus;
        });
      }

      print('🔄 [HomeScreen] Job $jobId: ${jobStatus.status} (${jobStatus.progress}%)');

      // Stop polling if job is completed or failed
      if (jobStatus.isCompleted || jobStatus.isFailed) {
        _jobPollingTimer?.cancel();

        if (jobStatus.isCompleted) {
          // Reset retry count on success
          _retryCount = 0;

          // Refresh speakers list
          await _fetchSpeakers();

          Fluttertoast.showToast(
            msg: "Processing completed successfully!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
        } else if (jobStatus.isFailed) {
          // Auto-retry logic
          if (_retryCount < _maxRetries) {
            _retryCount++;
            final retryDelay = Duration(seconds: 2 * _retryCount); // Exponential backoff: 2s, 4s, 6s

            print('⚠️ [HomeScreen] Job failed. Auto-retry ${_retryCount}/$_maxRetries in ${retryDelay.inSeconds}s');

            Fluttertoast.showToast(
              msg: "Job failed. Retrying in ${retryDelay.inSeconds}s... (${_retryCount}/$_maxRetries)",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.orange,
              textColor: Colors.white,
            );

            // Schedule retry
            _retryTimer?.cancel();
            _retryTimer = Timer(retryDelay, () {
              print('🔄 [HomeScreen] Auto-retrying job $jobId');
              _startJobPolling(jobId);
            });
          } else {
            print('❌ [HomeScreen] Max retries reached for job $jobId');
            Fluttertoast.showToast(
              msg: "Processing failed after $_maxRetries attempts",
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
        }
      }
    } catch (e) {
      print('❌ [HomeScreen] Error polling job status: $e');
    }
  }

  /// Dismiss the current job progress bar
  void _dismissJob() {
    _jobPollingTimer?.cancel();
    _retryTimer?.cancel();
    setState(() {
      _currentJob = null;
      _retryCount = 0;
    });
  }

  /// Manual retry - triggered by retry button
  void _retryJob() {
    if (_currentJob != null) {
      print('🔄 [HomeScreen] Manual retry for job: ${_currentJob!.jobId}');

      // Cancel any pending auto-retry
      _retryTimer?.cancel();

      // Reset retry count for manual retry
      _retryCount = 0;

      // Start polling again
      _startJobPolling(_currentJob!.jobId);

      Fluttertoast.showToast(
        msg: "Retrying job...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.blue,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _onViewRecordingsTap(BuildContext context) async {
    // Close drawer first
    _drawerKey.currentState?.toggleDrawer();

    // Navigate to recordings screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RecordingsScreen(),
      ),
    );
  }

  Future<void> _onChangeFolderTap(BuildContext context) async {
    try {
      // Close drawer first
      _drawerKey.currentState?.toggleDrawer();

      // Show folder picker
      print('📁 [HomeScreen] Opening folder picker');
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        print('📁 [HomeScreen] Folder selected: $selectedDirectory');

        // Stop monitoring first
        await ref.read(fileMonitorProvider.notifier).stopMonitoring();

        // Update config with new folder
        await ref.read(configProvider.notifier).updateFolderPath(selectedDirectory);

        // Start monitoring with new folder
        await ref.read(fileMonitorProvider.notifier).startMonitoring(selectedDirectory);

        print('✅ [HomeScreen] Folder changed successfully to: $selectedDirectory');

        // Show success toast
        Fluttertoast.showToast(
          msg: "Folder changed successfully!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        print('⏭️  [HomeScreen] Folder selection cancelled');
      }
    } catch (e) {
      print('❌ [HomeScreen] Error changing folder: $e');

      // Show error toast
      Fluttertoast.showToast(
        msg: "Error changing folder: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configProvider);
    final fileMonitorState = ref.watch(fileMonitorProvider);
    final config = configAsync.value;

    return Drawer3D(
      key: _drawerKey,
      isMonitoring: fileMonitorState.isMonitoring,
      monitoredFolderPath: config?.monitoredFolderPath ?? 'No folder selected',
      onViewRecordingsTap: () => _onViewRecordingsTap(context),
      onChangeFolderTap: () => _onChangeFolderTap(context),
      child: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (config) {
          if (config == null || !config.isOnboardingComplete) {
            return const Center(
              child: Text('Configuration not found'),
            );
          }

          return Scaffold(
            bottomNavigationBar: _currentJob != null
                ? UploadProgressBar(
                    jobStatus: _currentJob!,
                    onDismiss: _dismissJob,
                    onRetry: _retryJob,
                  )
                : null,
            body: AnimatedBuilder(
              animation: _gradientAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(
                          Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
                          _gradientAnimation.value,
                        )!,
                        Theme.of(context).colorScheme.surface,
                      ],
                      stops: const [0.0,  1.0],
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 100),
                      Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          // Refresh speakers from API
                          await _refreshSpeakers();

                          // Also restart file monitoring
                          await ref
                              .read(fileMonitorProvider.notifier)
                              .stopMonitoring();
                          await ref
                              .read(fileMonitorProvider.notifier)
                              .startMonitoring(config.monitoredFolderPath);
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 16),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.all(16.0),
                              sliver: _buildUserGrid(context, isLoading: false),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 100),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserGrid(BuildContext context, {required bool isLoading}) {
    if (_isLoadingSpeakers || isLoading) {
      return _buildShimmerGrid(context);
    }

    // Show error if speakers failed to load
    if (_speakersError != null) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Failed to load speakers',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _speakersError!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _fetchSpeakers,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show empty state if no speakers
    if (_speakers == null || _speakers!.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No speakers found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload audio files to see speaker insights',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final speaker = _speakers![index];
          return _buildSpeakerCard(context, speaker);
        },
        childCount: _speakers!.length,
      ),
    );
  }

  Widget _buildShimmerGrid(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildShimmerCard(context),
        childCount: 9,
      ),
    );
  }

  Widget _buildShimmerCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large circular avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 16),
              // Name placeholder
              Container(
                width: 70,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              // Duration placeholder
              Container(
                width: 50,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              // File count placeholder
              Container(
                width: 40,
                height: 11,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    // Get first letter of first name and first letter of last name
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  Widget _buildSpeakerCard(BuildContext context, Speaker speaker) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Generate a color based on the speaker's name for visual variety
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
    ];
    final displayName = _nameCache[speaker.speakerId] ?? speaker.name;
    final colorIndex = displayName.hashCode % colors.length;
    final avatarColor = colors[colorIndex];
    final speakerId = speaker.speakerId;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => InsightDetailScreen(
                  speakerId: speakerId,
                  userName: displayName,
                  duration: speaker.getFormattedDuration(),
                  fileCount: speaker.fileCount,
                  avatarColor: avatarColor,
                  initialAvatarImagePath: _avatarCache[speakerId],
                ),
              ),
            );
            // Reload speakers after returning
            await _fetchSpeakers();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large circular avatar with gradient
                Hero(
                  tag: 'avatar_$displayName',
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _avatarCache[speakerId] == null
                            ? LinearGradient(
                                colors: [
                                  Color.lerp(avatarColor, Colors.white, 0.3)!,
                                  avatarColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        image: _avatarCache[speakerId] != null
                            ? DecorationImage(
                                image: FileImage(File(_avatarCache[speakerId]!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: avatarColor.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _avatarCache[speakerId] == null
                          ? Center(
                              child: Text(
                                _getInitials(displayName),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Name with better typography
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Duration with icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      speaker.getFormattedDuration(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // File count with subtle background
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${speaker.fileCount} files',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
