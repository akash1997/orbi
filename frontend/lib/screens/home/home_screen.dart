import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/config_provider.dart';
import '../../providers/file_monitor_provider.dart';
import '../../widgets/drawer_3d.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _drawerKey = GlobalKey<Drawer3DState>();

  @override
  void initState() {
    super.initState();
    // Start monitoring when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMonitoring();
    });
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

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(fileMonitorProvider.notifier)
                  .stopMonitoring();
              await ref
                  .read(fileMonitorProvider.notifier)
                  .startMonitoring(config.monitoredFolderPath);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 80), // Space for header

                    // Detected Files Section
                    _buildDetectedFilesSection(
                      context,
                      fileMonitorState.detectedFiles,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetectedFilesSection(
    BuildContext context,
    List detectedFiles,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Detected Files',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (detectedFiles.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.audio_file,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No audio files detected yet',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Record audio in your monitored folder to see it here',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: detectedFiles.length,
            itemBuilder: (context, index) {
              final file = detectedFiles[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.audio_file,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    file.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a')
                            .format(file.detectedAt),
                      ),
                      Text(
                        '${(file.fileSize / 1024).toStringAsFixed(2)} KB',
                      ),
                    ],
                  ),
                  trailing: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
