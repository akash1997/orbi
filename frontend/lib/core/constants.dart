class AppConstants {
  // API - Use local IP address to allow mobile device access
  static const String baseUrl = 'http://10.206.160.145:8000';
  static const String uploadEndpoint = '/upload';

  // Audio Extensions
  static const List<String> audioExtensions = [
    '.mp3',
    '.m4a',
    '.wav',
    '.aac',
    '.opus',
  ];
}
