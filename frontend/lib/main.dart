import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'services/database_service.dart';
import 'services/speaker_profile_service.dart';
import 'providers/config_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/speaker_profile_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 [Main] Initializing Orbi app');

  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize database
  final databaseService = DatabaseService();
  await databaseService.initialize();
  print('✅ [Main] Database initialized');

  // Initialize speaker profile service
  final speakerProfileService = SpeakerProfileService(prefs);
  print('✅ [Main] Speaker profile service initialized');

  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(databaseService),
        themeProvider.overrideWith((ref) => ThemeNotifier(prefs)),
        speakerProfileServiceProvider.overrideWithValue(speakerProfileService),
      ],
      child: const OrbiApp(),
    ),
  );
}

class OrbiApp extends ConsumerWidget {
  const OrbiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Orbi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AppInitializer(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
    );
  }
}

class AppInitializer extends ConsumerWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configProvider);

    return configAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) {
        print('❌ [Main] Error loading config: $error');
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Retry loading
                    ref.invalidate(configProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
      data: (config) {
        print('📋 [Main] Config loaded: ${config?.monitoredFolderPath}');
        print('📋 [Main] Onboarding complete: ${config?.isOnboardingComplete}');

        // Navigate based on onboarding status
        if (config == null || !config.isOnboardingComplete) {
          print('🎯 [Main] Navigating to onboarding');
          return const OnboardingScreen();
        } else {
          print('🎯 [Main] Navigating to home');
          return const HomeScreen();
        }
      },
    );
  }
}
