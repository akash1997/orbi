import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsPage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const PermissionsPage({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  bool _isGranted = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isChecking = true);

    // Check for manage external storage permission (for full file access)
    final status = await Permission.manageExternalStorage.status;
    print('📋 [Permissions] Manage external storage status: $status');

    setState(() {
      _isGranted = status.isGranted;
      _isChecking = false;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _isChecking = true);

    print('📋 [Permissions] Requesting manage external storage permission');

    // Request manage external storage permission
    final status = await Permission.manageExternalStorage.request();
    print('📋 [Permissions] Permission result: $status');

    setState(() {
      _isGranted = status.isGranted;
      _isChecking = false;
    });

    if (_isGranted) {
      print('✅ [Permissions] Storage permission granted');
    } else {
      print('❌ [Permissions] Storage permission denied');

      // If denied, show option to open settings
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please grant "All files access" in settings'),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () => openAppSettings(),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Permission Icon
              Icon(
                _isGranted ? Icons.check_circle : Icons.folder_open,
                size: 80,
                color: _isGranted
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Storage Permission',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'Orbi needs permission to access your device storage to monitor the folder where audio recordings are saved.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Permission Status
              if (_isGranted)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Permission granted',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              // Grant Permission Button
              if (!_isGranted)
                FilledButton(
                  onPressed: _isChecking ? null : _requestPermissions,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: _isChecking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Grant Permission'),
                  ),
                ),

              // Continue Button
              if (_isGranted)
                FilledButton(
                  onPressed: widget.onNext,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('Continue'),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
