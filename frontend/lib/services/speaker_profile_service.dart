import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class SpeakerProfile {
  final String id;
  final String name;
  final String? avatarImagePath;

  SpeakerProfile({
    required this.id,
    required this.name,
    this.avatarImagePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarImagePath': avatarImagePath,
      };

  factory SpeakerProfile.fromJson(Map<String, dynamic> json) {
    return SpeakerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarImagePath: json['avatarImagePath'] as String?,
    );
  }
}

class SpeakerProfileService {
  static const String _profilePrefix = 'speaker_profile_';
  static const String _profileListKey = 'speaker_profile_list';

  final SharedPreferences _prefs;

  SpeakerProfileService(this._prefs);

  /// Get the directory for storing avatar images
  Future<Directory> get _avatarDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory(path.join(appDir.path, 'avatars'));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    return avatarDir;
  }

  /// Save or update a speaker profile
  Future<void> saveProfile(SpeakerProfile profile) async {
    // Save profile data
    final key = '$_profilePrefix${profile.id}';
    final json = profile.toJson();
    await _prefs.setString(key, json.toString());

    // Update profile list
    final profileIds = _prefs.getStringList(_profileListKey) ?? [];
    if (!profileIds.contains(profile.id)) {
      profileIds.add(profile.id);
      await _prefs.setStringList(_profileListKey, profileIds);
    }

    print('✅ [SpeakerProfileService] Profile saved: ${profile.id}');
  }

  /// Get a speaker profile by ID
  Future<SpeakerProfile?> getProfile(String id) async {
    final key = '$_profilePrefix$id';
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;

    try {
      // Parse the stored string back to a map
      final json = _parseJsonString(jsonString);
      return SpeakerProfile.fromJson(json);
    } catch (e) {
      print('❌ [SpeakerProfileService] Error parsing profile: $e');
      return null;
    }
  }

  /// Get all speaker profiles
  Future<List<SpeakerProfile>> getAllProfiles() async {
    final profileIds = _prefs.getStringList(_profileListKey) ?? [];
    final profiles = <SpeakerProfile>[];

    for (final id in profileIds) {
      final profile = await getProfile(id);
      if (profile != null) {
        profiles.add(profile);
      }
    }

    return profiles;
  }

  /// Save avatar image and return the file path
  Future<String> saveAvatarImage(String speakerId, String sourcePath) async {
    final avatarDir = await _avatarDirectory;
    final extension = path.extension(sourcePath);
    final fileName = '$speakerId$extension';
    final targetPath = path.join(avatarDir.path, fileName);

    // Copy the image file
    final sourceFile = File(sourcePath);
    await sourceFile.copy(targetPath);

    print('✅ [SpeakerProfileService] Avatar saved: $targetPath');
    return targetPath;
  }

  /// Delete avatar image
  Future<void> deleteAvatarImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        print('✅ [SpeakerProfileService] Avatar deleted: $imagePath');
      }
    } catch (e) {
      print('❌ [SpeakerProfileService] Error deleting avatar: $e');
    }
  }

  /// Update speaker name
  Future<void> updateSpeakerName(String id, String newName) async {
    final profile = await getProfile(id);
    if (profile != null) {
      final updatedProfile = SpeakerProfile(
        id: id,
        name: newName,
        avatarImagePath: profile.avatarImagePath,
      );
      await saveProfile(updatedProfile);
    }
  }

  /// Update speaker avatar
  Future<void> updateSpeakerAvatar(String id, String imagePath) async {
    final profile = await getProfile(id);
    if (profile != null) {
      // Delete old avatar if exists
      if (profile.avatarImagePath != null) {
        await deleteAvatarImage(profile.avatarImagePath!);
      }

      // Save new avatar
      final newAvatarPath = await saveAvatarImage(id, imagePath);

      // Update profile
      final updatedProfile = SpeakerProfile(
        id: id,
        name: profile.name,
        avatarImagePath: newAvatarPath,
      );
      await saveProfile(updatedProfile);
    }
  }

  /// Delete a speaker profile
  Future<void> deleteProfile(String id) async {
    final profile = await getProfile(id);
    if (profile != null && profile.avatarImagePath != null) {
      await deleteAvatarImage(profile.avatarImagePath!);
    }

    final key = '$_profilePrefix$id';
    await _prefs.remove(key);

    final profileIds = _prefs.getStringList(_profileListKey) ?? [];
    profileIds.remove(id);
    await _prefs.setStringList(_profileListKey, profileIds);

    print('✅ [SpeakerProfileService] Profile deleted: $id');
  }

  /// Parse JSON string to Map (simple parser for our use case)
  Map<String, dynamic> _parseJsonString(String jsonString) {
    // Remove outer braces and split by comma
    final cleaned = jsonString.substring(1, jsonString.length - 1);
    final pairs = cleaned.split(', ');
    final map = <String, dynamic>{};

    for (final pair in pairs) {
      final parts = pair.split(': ');
      if (parts.length == 2) {
        final key = parts[0];
        var value = parts[1];
        // Remove quotes if present
        if (value.startsWith("'") && value.endsWith("'")) {
          value = value.substring(1, value.length - 1);
        }
        if (value == 'null') {
          map[key] = null;
        } else {
          map[key] = value;
        }
      }
    }

    return map;
  }
}
