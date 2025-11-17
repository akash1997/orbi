class AudioFileModel {
  final String fileName;
  final String filePath;
  final DateTime detectedAt;
  final int fileSize;

  AudioFileModel({
    required this.fileName,
    required this.filePath,
    required this.detectedAt,
    required this.fileSize,
  });
}
