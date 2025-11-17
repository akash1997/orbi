import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/speaker_profile_provider.dart';
import '../../services/speaker_profile_service.dart';

class InsightDetailScreen extends ConsumerStatefulWidget {
  final String userName;
  final String duration;
  final int fileCount;
  final Color avatarColor;
  final String? initialAvatarImagePath;

  const InsightDetailScreen({
    super.key,
    required this.userName,
    required this.duration,
    required this.fileCount,
    required this.avatarColor,
    this.initialAvatarImagePath,
  });

  @override
  ConsumerState<InsightDetailScreen> createState() => _InsightDetailScreenState();
}

class _InsightDetailScreenState extends ConsumerState<InsightDetailScreen> {
  late String _currentName;
  String? _avatarImagePath;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentName = widget.userName;
    _avatarImagePath = widget.initialAvatarImagePath;
    _nameController.text = _currentName;
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _speakerId => widget.userName.toLowerCase().replaceAll(' ', '_');

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    // Get first letter of first name and first letter of last name
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  Future<void> _loadProfile() async {
    final service = ref.read(speakerProfileServiceProvider);
    final profile = await service.getProfile(_speakerId);

    if (profile != null) {
      setState(() {
        _currentName = profile.name;
        _avatarImagePath = profile.avatarImagePath;
        _nameController.text = _currentName;
      });
    } else {
      // Create initial profile
      final newProfile = SpeakerProfile(
        id: _speakerId,
        name: widget.userName,
      );
      await service.saveProfile(newProfile);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final imagePath = result.files.single.path!;
        final service = ref.read(speakerProfileServiceProvider);
        await service.updateSpeakerAvatar(_speakerId, imagePath);

        setState(() {
          _avatarImagePath = imagePath;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar updated successfully')),
          );
        }
      }
    } catch (e) {
      print('❌ [InsightDetailScreen] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating avatar: $e')),
        );
      }
    }
  }

  Future<void> _editName() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Speaker Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Speaker Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty && newName != _currentName) {
                final service = ref.read(speakerProfileServiceProvider);
                await service.updateSpeakerName(_speakerId, newName);

                setState(() {
                  _currentName = newName;
                });

                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name updated successfully')),
                  );
                }
              } else {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Insight Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Avatar and Name Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.avatarColor.withOpacity(0.1),
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Hero Avatar with Edit Button
                  Stack(
                    children: [
                      Hero(
                        tag: 'avatar_${widget.userName}',
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _avatarImagePath == null
                                  ? LinearGradient(
                                      colors: [
                                        Color.lerp(widget.avatarColor, Colors.white, 0.3)!,
                                        widget.avatarColor,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              image: _avatarImagePath != null
                                  ? DecorationImage(
                                      image: FileImage(File(_avatarImagePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.avatarColor.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _avatarImagePath == null
                                ? Center(
                                    child: Text(
                                      _getInitials(_currentName),
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Material(
                          color: Theme.of(context).colorScheme.primary,
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: InkWell(
                            onTap: _pickImage,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Speaker Name with Edit Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _editName,
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Edit name',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Duration Card
                  _buildInfoCard(
                    context,
                    icon: Icons.access_time,
                    title: 'Total Duration',
                    value: widget.duration,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),

                  // File Count Card
                  _buildInfoCard(
                    context,
                    icon: Icons.audio_file,
                    title: 'Audio Files',
                    value: '${widget.fileCount} files',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 32),

                  // Section Title
                  Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Placeholder for activity list
                  _buildActivityItem(
                    context,
                    'Recording analyzed',
                    '2 hours ago',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildActivityItem(
                    context,
                    'Voice pattern detected',
                    '5 hours ago',
                    Icons.graphic_eq,
                    Colors.blue,
                  ),
                  _buildActivityItem(
                    context,
                    'New audio file added',
                    '1 day ago',
                    Icons.add_circle,
                    Colors.orange,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
