import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/config_provider.dart';
import 'welcome_page.dart';
import 'permissions_page.dart';
import 'folder_selection_page.dart';
import 'completion_page.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _selectedFolder;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onFolderSelected(String folderPath) {
    setState(() {
      _selectedFolder = folderPath;
    });
    _nextPage();
  }

  Future<void> _completeOnboarding() async {
    if (_selectedFolder != null) {
      print('🎉 [Onboarding] Completing onboarding');
      await ref
          .read(configProvider.notifier)
          .completeOnboarding(_selectedFolder!);

      if (mounted) {
        // Navigate to home screen
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Progress Indicator
          if (_currentPage > 0)
            LinearProgressIndicator(
              value: (_currentPage + 1) / 4,
              backgroundColor: Colors.transparent,
            ),

          // Page View
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                // Page 1: Welcome
                WelcomePage(onNext: _nextPage),

                // Page 2: Permissions
                PermissionsPage(
                  onNext: _nextPage,
                  onBack: _previousPage,
                ),

                // Page 3: Folder Selection
                FolderSelectionPage(
                  onFolderSelected: _onFolderSelected,
                  onBack: _previousPage,
                ),

                // Page 4: Completion
                CompletionPage(
                  onComplete: _completeOnboarding,
                  selectedFolder: _selectedFolder ?? '',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
