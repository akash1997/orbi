import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config_model.dart';

class DatabaseService {
  static const String _folderPathKey = 'monitored_folder_path';
  static const String _onboardingCompleteKey = 'is_onboarding_complete';

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveConfig(AppConfigModel config) async {
    await _prefs?.setString(_folderPathKey, config.monitoredFolderPath);
    await _prefs?.setBool(_onboardingCompleteKey, config.isOnboardingComplete);
  }

  AppConfigModel? getConfig() {
    final folderPath = _prefs?.getString(_folderPathKey);
    final isOnboardingComplete = _prefs?.getBool(_onboardingCompleteKey) ?? false;

    if (folderPath == null) {
      return null;
    }

    return AppConfigModel(
      monitoredFolderPath: folderPath,
      isOnboardingComplete: isOnboardingComplete,
    );
  }

  Future<void> clearConfig() async {
    await _prefs?.remove(_folderPathKey);
    await _prefs?.remove(_onboardingCompleteKey);
  }
}
