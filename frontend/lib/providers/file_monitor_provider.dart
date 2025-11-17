import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_file_model.dart';
import '../services/file_watcher_service.dart';
import '../services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

class FileMonitorState {
  final bool isMonitoring;
  final List<AudioFileModel> detectedFiles;
  final String? error;

  FileMonitorState({
    this.isMonitoring = false,
    this.detectedFiles = const [],
    this.error,
  });

  FileMonitorState copyWith({
    bool? isMonitoring,
    List<AudioFileModel>? detectedFiles,
    String? error,
  }) {
    return FileMonitorState(
      isMonitoring: isMonitoring ?? this.isMonitoring,
      detectedFiles: detectedFiles ?? this.detectedFiles,
      error: error,
    );
  }
}

class FileMonitorNotifier extends StateNotifier<FileMonitorState> {
  final ApiService _apiService;
  FileWatcherService? _fileWatcherService;

  FileMonitorNotifier(this._apiService) : super(FileMonitorState());

  Future<void> startMonitoring(String folderPath) async {
    try {
      print('🚀 [FileMonitorProvider] Starting monitoring for: $folderPath');

      // Create file watcher service
      _fileWatcherService = FileWatcherService(
        onFileDetected: _handleFileDetected,
      );

      // Start watching
      await _fileWatcherService!.startWatching(folderPath);

      state = state.copyWith(
        isMonitoring: true,
        error: null,
      );

      print('✅ [FileMonitorProvider] Monitoring started');
    } catch (e) {
      print('❌ [FileMonitorProvider] Error starting monitoring: $e');
      state = state.copyWith(
        isMonitoring: false,
        error: e.toString(),
      );
    }
  }

  Future<void> stopMonitoring() async {
    try {
      print('🛑 [FileMonitorProvider] Stopping monitoring');
      await _fileWatcherService?.stopWatching();
      _fileWatcherService = null;

      state = state.copyWith(
        isMonitoring: false,
        error: null,
      );

      print('✅ [FileMonitorProvider] Monitoring stopped');
    } catch (e) {
      print('❌ [FileMonitorProvider] Error stopping monitoring: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  void _handleFileDetected(AudioFileModel audioFile) {
    print('📥 [FileMonitorProvider] File detected: ${audioFile.fileName}');

    // Add to detected files list
    final updatedFiles = [...state.detectedFiles, audioFile];
    state = state.copyWith(detectedFiles: updatedFiles);

    // Upload file
    _uploadFile(audioFile);
  }

  Future<void> _uploadFile(AudioFileModel audioFile) async {
    try {
      print('📤 [FileMonitorProvider] Uploading: ${audioFile.fileName}');
      final file = File(audioFile.filePath);

      if (await file.exists()) {
        await _apiService.uploadAudioFile(file);
        print('✅ [FileMonitorProvider] Upload completed for: ${audioFile.fileName}');
      } else {
        print('❌ [FileMonitorProvider] File not found: ${audioFile.filePath}');
      }
    } catch (e) {
      print('❌ [FileMonitorProvider] Upload error: $e');
      // Don't update error state for upload failures in Phase 1
      // We expect uploads to fail since backend is not ready
    }
  }

  void clearDetectedFiles() {
    print('🗑️  [FileMonitorProvider] Clearing detected files');
    state = state.copyWith(detectedFiles: []);
  }
}

final fileMonitorProvider =
    StateNotifierProvider<FileMonitorNotifier, FileMonitorState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return FileMonitorNotifier(apiService);
});
