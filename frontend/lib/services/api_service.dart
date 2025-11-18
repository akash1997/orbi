import 'dart:io';
import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/speaker_model.dart';

class ApiService {
  final Dio _dio;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConstants.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// Upload audio file to backend
  /// For Phase 1: Just logs the attempt, doesn't expect success
  Future<void> uploadAudioFile(File file) async {
    try {
      print('📤 [API] Attempting to upload: ${file.path}');

      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      print('📤 [API] Calling POST ${AppConstants.baseUrl}${AppConstants.uploadEndpoint}');

      final response = await _dio.post(
        AppConstants.uploadEndpoint,
        data: formData,
      );

      print('✅ [API] Upload successful! Status: ${response.statusCode}');
      print('✅ [API] Response: ${response.data}');
    } on DioException catch (e) {
      // Expected to fail since backend not ready
      print('❌ [API] Upload failed (expected): ${e.type}');
      print('❌ [API] Error message: ${e.message}');

      // Don't throw error in Phase 1 - just log it
      // This allows testing without backend
    } catch (e) {
      print('❌ [API] Unexpected error: $e');
    }
  }

  /// Fetch all speakers from the backend
  Future<List<Speaker>> fetchSpeakers({int limit = 100, int offset = 0}) async {
    try {
      print('🔍 [API] Fetching speakers from: ${AppConstants.baseUrl}/speakers');
      print('🔍 [API] Query params - limit: $limit, offset: $offset');

      final response = await _dio.get(
        '/speakers',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      print('✅ [API] Response Status: ${response.statusCode}');
      print('✅ [API] Response Headers: ${response.headers}');
      print('✅ [API] Response Data: ${response.data}');
      print('✅ [API] Speakers fetched successfully! Count: ${(response.data as List).length}');

      final List<dynamic> speakersJson = response.data as List;
      final speakers = speakersJson.map((json) => Speaker.fromJson(json as Map<String, dynamic>)).toList();

      print('✅ [API] Parsed speakers:');
      for (var speaker in speakers) {
        print('   - ${speaker.name} (${speaker.speakerId}): ${speaker.fileCount} files, ${speaker.getFormattedDuration()}');
      }

      return speakers;
    } on DioException catch (e) {
      print('❌ [API] Failed to fetch speakers: ${e.type}');
      print('❌ [API] Error message: ${e.message}');
      print('❌ [API] Response data: ${e.response?.data}');
      print('❌ [API] Status code: ${e.response?.statusCode}');
      rethrow;
    } catch (e) {
      print('❌ [API] Unexpected error fetching speakers: $e');
      rethrow;
    }
  }
}
