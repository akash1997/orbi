import 'dart:io';
import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/speaker_model.dart';
import '../models/upload_response.dart';
import '../models/job_status.dart';
import '../models/recording_model.dart';
import '../models/recording_list_model.dart';

class ApiService {
  final Dio _dio;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConstants.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// Upload audio file to backend and get job ID
  Future<UploadResponse> uploadAudioFile(File file) async {
    try {
      print('📤 [API] Uploading file: ${file.path}');

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

      return UploadResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('❌ [API] Upload failed: ${e.type}');
      print('❌ [API] Error message: ${e.message}');
      print('❌ [API] Response data: ${e.response?.data}');
      print('❌ [API] Status code: ${e.response?.statusCode}');
      rethrow;
    } catch (e) {
      print('❌ [API] Unexpected error during upload: $e');
      rethrow;
    }
  }

  /// Get job status by job ID
  Future<JobStatus> getJobStatus(String jobId) async {
    try {
      print('🔍 [API] Fetching job status for: $jobId');

      final response = await _dio.get('/jobs/$jobId');

      print('✅ [API] Job status fetched: ${response.data}');

      return JobStatus.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('❌ [API] Failed to fetch job status: ${e.type}');
      print('❌ [API] Error message: ${e.message}');
      print('❌ [API] Response data: ${e.response?.data}');
      rethrow;
    } catch (e) {
      print('❌ [API] Unexpected error fetching job status: $e');
      rethrow;
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

  /// Fetch a single speaker by ID from the backend
  Future<Speaker> getSpeaker(String speakerId) async {
    try {
      print('🔍 [API] Fetching speaker: $speakerId from ${AppConstants.baseUrl}/speakers/$speakerId');

      final response = await _dio.get('/speakers/$speakerId');

      print('✅ [API] Response Status: ${response.statusCode}');
      print('✅ [API] Response Data: ${response.data}');
      print('✅ [API] Speaker fetched successfully!');

      final speaker = Speaker.fromJson(response.data as Map<String, dynamic>);

      print('✅ [API] Parsed speaker: ${speaker.name} (${speaker.speakerId}): ${speaker.fileCount} files, ${speaker.getFormattedDuration()}');

      return speaker;
    } on DioException catch (e) {
      print('❌ [API] Failed to fetch speaker: ${e.type}');
      print('❌ [API] Error message: ${e.message}');
      print('❌ [API] Response data: ${e.response?.data}');
      print('❌ [API] Status code: ${e.response?.statusCode}');
      rethrow;
    } catch (e) {
      print('❌ [API] Unexpected error fetching speaker: $e');
      rethrow;
    }
  }

  /// Fetch all recordings list
  Future<List<RecordingListItem>> fetchRecordings({int limit = 100, int offset = 0}) async {
    try {
      print('🔍 [API] Fetching recordings list');

      final response = await _dio.get('/recordings', queryParameters: {
        'limit': limit,
        'offset': offset,
      });

      final List<dynamic> recordingsList = response.data as List<dynamic>;
      print('✅ [API] Fetched ${recordingsList.length} recordings');

      return recordingsList
          .map((json) => RecordingListItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      print('❌ [API] Failed to fetch recordings: ${e.type}');
      print('❌ [API] Error message: ${e.message}');
      if (e.response != null) {
        print('❌ [API] Response data: ${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      print('❌ [API] Unexpected error fetching recordings: $e');
      rethrow;
    }
  }

  /// Fetch recording details by audio file ID
  Future<RecordingDetail> fetchRecordingDetails(String audioFileId) async {
    try {
      print('🔍 [API] Fetching recording details for: $audioFileId');

      final response = await _dio.get('/recordings/$audioFileId');

      print('✅ [API] Recording details fetched successfully');
      return RecordingDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('❌ [API] Failed to fetch recording details: ${e.type}');
      print('❌ [API] Error message: ${e.message}');
      print('❌ [API] Response data: ${e.response?.data}');
      rethrow;
    } catch (e) {
      print('❌ [API] Unexpected error fetching recording details: $e');
      rethrow;
    }
  }
}
