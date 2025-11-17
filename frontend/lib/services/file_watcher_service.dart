import 'dart:io';
import 'dart:async';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as path;
import '../models/audio_file_model.dart';
import '../core/constants.dart';

class FileWatcherService {
  StreamSubscription? _watcherSubscription;
  final void Function(AudioFileModel) onFileDetected;

  FileWatcherService({required this.onFileDetected});

  /// Start watching a folder for new audio files
  Future<void> startWatching(String folderPath) async {
    print('👀 [Watcher] Starting to watch: $folderPath');

    final directory = Directory(folderPath);

    if (!await directory.exists()) {
      print('❌ [Watcher] Directory does not exist: $folderPath');
      throw Exception('Directory does not exist: $folderPath');
    }

    // Create directory watcher
    final watcher = DirectoryWatcher(folderPath);

    // Listen for file system events
    _watcherSubscription = watcher.events.listen((event) {
      print('📁 [Watcher] Event: ${event.type} - ${event.path}');

      if (event.type == ChangeType.ADD) {
        _handleNewFile(event.path);
      }
    });

    print('✅ [Watcher] Now monitoring folder');
  }

  /// Stop watching
  Future<void> stopWatching() async {
    await _watcherSubscription?.cancel();
    _watcherSubscription = null;
    print('🛑 [Watcher] Stopped monitoring');
  }

  /// Handle newly detected file
  Future<void> _handleNewFile(String filePath) async {
    print('🔍 [Watcher] Checking file: $filePath');

    // Check if it's an audio file
    if (!_isAudioFile(filePath)) {
      print('⏭️  [Watcher] Not an audio file, skipping');
      return;
    }

    // Wait for file to be completely written
    await _waitForFileStability(filePath);

    // Create model
    final file = File(filePath);
    final stat = await file.stat();

    final audioFile = AudioFileModel(
      fileName: path.basename(filePath),
      filePath: filePath,
      detectedAt: DateTime.now(),
      fileSize: stat.size,
    );

    print('🎵 [Watcher] Audio file detected: ${audioFile.fileName}');
    print('🎵 [Watcher] Size: ${audioFile.fileSize} bytes');

    // Notify callback
    onFileDetected(audioFile);
  }

  /// Check if file is audio based on extension
  bool _isAudioFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return AppConstants.audioExtensions.contains(extension);
  }

  /// Wait for file to stop changing (ensure it's fully written)
  Future<void> _waitForFileStability(String filePath) async {
    final file = File(filePath);
    int lastSize = -1;
    int attempts = 0;
    const maxAttempts = 10;

    while (attempts < maxAttempts) {
      if (!await file.exists()) {
        print('⚠️  [Watcher] File disappeared: $filePath');
        return;
      }

      final currentSize = await file.length();

      if (currentSize == lastSize) {
        print('✅ [Watcher] File stable at $currentSize bytes');
        return; // File is stable
      }

      lastSize = currentSize;
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    print('⚠️  [Watcher] File still changing after $maxAttempts attempts');
  }
}
