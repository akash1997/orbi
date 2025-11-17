class AppConfigModel {
  final String monitoredFolderPath;
  final bool isOnboardingComplete;

  AppConfigModel({
    required this.monitoredFolderPath,
    this.isOnboardingComplete = false,
  });

  AppConfigModel copyWith({
    String? monitoredFolderPath,
    bool? isOnboardingComplete,
  }) {
    return AppConfigModel(
      monitoredFolderPath: monitoredFolderPath ?? this.monitoredFolderPath,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
    );
  }
}
