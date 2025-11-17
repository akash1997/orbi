import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/config_provider.dart';
import '../../providers/file_monitor_provider.dart';
import '../../providers/speaker_profile_provider.dart';
import '../../widgets/drawer_3d.dart';
import '../insights/insight_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shimmer/shimmer.dart';

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
      _loadAvatarProfiles();
    });
  }

  @override
  void dispose() {
    _gradientController.dispose();
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

  Future<void> _loadAvatarProfiles() async {
    final mockUsers = [
      {'name': 'Alice Johnson', 'duration': '2h 45m', 'fileCount': 8},
      {'name': 'Bob Smith', 'duration': '1h 30m', 'fileCount': 5},
      {'name': 'Carol Davis', 'duration': '3h 15m', 'fileCount': 12},
      {'name': 'David Wilson', 'duration': '45m', 'fileCount': 3},
      {'name': 'Emma Brown', 'duration': '2h 20m', 'fileCount': 7},
      {'name': 'Frank Miller', 'duration': '1h 50m', 'fileCount': 6},
      {'name': 'Grace Lee', 'duration': '4h 10m', 'fileCount': 15},
      {'name': 'Henry Taylor', 'duration': '1h 15m', 'fileCount': 4},
      {'name': 'Iris Anderson', 'duration': '3h 30m', 'fileCount': 11},
      {'name': 'Jack Thomas', 'duration': '2h 5m', 'fileCount': 9},
    ];

    final service = ref.read(speakerProfileServiceProvider);
    for (var user in mockUsers) {
      final speakerId = user['name'].toString().toLowerCase().replaceAll(' ', '_');
      final profile = await service.getProfile(speakerId);
      if (mounted) {
        setState(() {
          _avatarCache[speakerId] = profile?.avatarImagePath;
        });
      }
    }
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

          return AnimatedBuilder(
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
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUserGrid(BuildContext context, {required bool isLoading}) {
    if (isLoading) {
      return _buildShimmerGrid(context);
    }

    // Mock data for demo purposes
    final mockUsers = [
      {'name': 'Alice Johnson', 'duration': '2h 45m', 'fileCount': 8},
      {'name': 'Bob Smith', 'duration': '1h 30m', 'fileCount': 5},
      {'name': 'Carol Davis', 'duration': '3h 15m', 'fileCount': 12},
      {'name': 'David Wilson', 'duration': '45m', 'fileCount': 3},
      {'name': 'Emma Brown', 'duration': '2h 20m', 'fileCount': 7},
      {'name': 'Frank Miller', 'duration': '1h 50m', 'fileCount': 6},
      {'name': 'Grace Lee', 'duration': '4h 10m', 'fileCount': 15},
      {'name': 'Henry Taylor', 'duration': '1h 15m', 'fileCount': 4},
      {'name': 'Iris Anderson', 'duration': '3h 30m', 'fileCount': 11},
      {'name': 'Jack Thomas', 'duration': '2h 5m', 'fileCount': 9},
    ];

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final user = mockUsers[index];
          return _buildUserCard(context, user);
        },
        childCount: mockUsers.length,
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

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Generate a color based on the user's name for visual variety
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
    final colorIndex = user['name'].toString().hashCode % colors.length;
    final avatarColor = colors[colorIndex];
    final speakerId = user['name'].toString().toLowerCase().replaceAll(' ', '_');

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
                  userName: user['name'],
                  duration: user['duration'],
                  fileCount: user['fileCount'],
                  avatarColor: avatarColor,
                  initialAvatarImagePath: _avatarCache[speakerId],
                ),
              ),
            );
            // Reload avatar profiles after returning
            await _loadAvatarProfiles();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large circular avatar with gradient
                Hero(
                  tag: 'avatar_${user['name']}',
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
                                _getInitials(user['name'].toString()),
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
                  user['name'],
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
                      user['duration'],
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
                    '${user['fileCount']} files',
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
