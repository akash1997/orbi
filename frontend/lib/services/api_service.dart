import 'dart:io';
import 'package:dio/dio.dart';
import '../core/constants.dart';

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
}
