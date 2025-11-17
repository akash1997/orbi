import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_config_model.dart';
import '../services/database_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

class ConfigNotifier extends StateNotifier<AsyncValue<AppConfigModel?>> {
  final DatabaseService _databaseService;

  ConfigNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      print('🔄 [ConfigProvider] Loading config from database');
      final config = _databaseService.getConfig();
      print('✅ [ConfigProvider] Config loaded: ${config?.monitoredFolderPath}');
      state = AsyncValue.data(config);
    } catch (e, stack) {
      print('❌ [ConfigProvider] Error loading config: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> saveConfig(AppConfigModel config) async {
    try {
      print('💾 [ConfigProvider] Saving config: ${config.monitoredFolderPath}');
      await _databaseService.saveConfig(config);
      state = AsyncValue.data(config);
      print('✅ [ConfigProvider] Config saved successfully');
    } catch (e, stack) {
      print('❌ [ConfigProvider] Error saving config: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateFolderPath(String newPath) async {
    final currentConfig = state.value;
    if (currentConfig != null) {
      print('📁 [ConfigProvider] Updating folder path to: $newPath');
      final updatedConfig = currentConfig.copyWith(monitoredFolderPath: newPath);
      await saveConfig(updatedConfig);
    } else {
      print('⚠️  [ConfigProvider] No existing config to update');
    }
  }

  Future<void> completeOnboarding(String folderPath) async {
    print('🎉 [ConfigProvider] Completing onboarding with folder: $folderPath');
    final config = AppConfigModel(
      monitoredFolderPath: folderPath,
      isOnboardingComplete: true,
    );
    await saveConfig(config);
  }

  Future<void> clearConfig() async {
    try {
      print('🗑️  [ConfigProvider] Clearing config');
      await _databaseService.clearConfig();
      state = const AsyncValue.data(null);
      print('✅ [ConfigProvider] Config cleared');
    } catch (e, stack) {
      print('❌ [ConfigProvider] Error clearing config: $e');
      state = AsyncValue.error(e, stack);
    }
  }
}

final configProvider =
    StateNotifierProvider<ConfigNotifier, AsyncValue<AppConfigModel?>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return ConfigNotifier(databaseService);
});
