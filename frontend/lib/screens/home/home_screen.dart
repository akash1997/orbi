import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/config_provider.dart';
import '../../providers/file_monitor_provider.dart';
import '../../widgets/drawer_3d.dart';
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
                      Color.lerp(
                        Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        _gradientAnimation.value,
                      )!,
                      Theme.of(context).colorScheme.surface,
                    ],
                    stops: const [0.0, 0.5, 1.0],
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
                              sliver: _buildUserGrid(context, isLoading: true),
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

    // TODO: Replace with actual user data
    final mockUsers = List.generate(
      10,
      (index) => {
        'name': 'User ${index + 1}',
        'duration': '${(index + 1) * 2}h ${(index + 1) * 15}m',
        'fileCount': (index + 1) * 3,
      },
    );

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
          onTap: () {
            // TODO: Navigate to user detail screen
            print('Tapped on ${user['name']}');
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large circular avatar with gradient
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        avatarColor.shade300,
                        avatarColor.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      user['name'].toString().substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
