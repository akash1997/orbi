import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class FolderSelectionPage extends StatefulWidget {
  final Function(String) onFolderSelected;
  final VoidCallback onBack;

  const FolderSelectionPage({
    super.key,
    required this.onFolderSelected,
    required this.onBack,
  });

  @override
  State<FolderSelectionPage> createState() => _FolderSelectionPageState();
}

class _FolderSelectionPageState extends State<FolderSelectionPage> {
  String? _selectedFolder;
  bool _isSelecting = false;

  Future<void> _selectFolder() async {
    setState(() => _isSelecting = true);

    try {
      print('📁 [FolderSelection] Opening folder picker');
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        print('📁 [FolderSelection] Folder selected: $selectedDirectory');
        setState(() {
          _selectedFolder = selectedDirectory;
        });
      } else {
        print('⏭️  [FolderSelection] Folder selection cancelled');
      }
    } catch (e) {
      print('❌ [FolderSelection] Error selecting folder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting folder: $e')),
        );
      }
    } finally {
      setState(() => _isSelecting = false);
    }
  }

  void _continue() {
    if (_selectedFolder != null) {
      print('✅ [FolderSelection] Continuing with folder: $_selectedFolder');
      widget.onFolderSelected(_selectedFolder!);
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

              // Folder Icon
              Icon(
                Icons.folder_special,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Select Audio Folder',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'Choose the folder where your voice recording app saves audio files. Orbi will monitor this folder for new recordings.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Selected Folder Display
              if (_selectedFolder != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.folder,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Selected Folder',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFolder!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              // Select Folder Button
              FilledButton.tonal(
                onPressed: _isSelecting ? null : _selectFolder,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: _isSelecting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.folder_open),
                            const SizedBox(width: 8),
                            Text(_selectedFolder == null
                                ? 'Select Folder'
                                : 'Change Folder'),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Continue Button
              FilledButton(
                onPressed: _selectedFolder == null ? null : _continue,
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
