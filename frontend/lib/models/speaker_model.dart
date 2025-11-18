class SpeakerFile {
  final String audioFileId;
  final String filename;
  final double durationInFile;
  final int segmentCount;
  final DateTime uploadedAt;

  SpeakerFile({
    required this.audioFileId,
    required this.filename,
    required this.durationInFile,
    required this.segmentCount,
    required this.uploadedAt,
  });

  factory SpeakerFile.fromJson(Map<String, dynamic> json) {
    return SpeakerFile(
      audioFileId: json['audio_file_id'] as String,
      filename: json['filename'] as String,
      durationInFile: (json['duration_in_file'] as num).toDouble(),
      segmentCount: json['segment_count'] as int,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audio_file_id': audioFileId,
      'filename': filename,
      'duration_in_file': durationInFile,
      'segment_count': segmentCount,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}

class Speaker {
  final String speakerId;
  final String name;
  final double totalDuration; // in seconds
  final int fileCount;
  final DateTime createdAt;
  final List<SpeakerFile> files;

  Speaker({
    required this.speakerId,
    required this.name,
    required this.totalDuration,
    required this.fileCount,
    required this.createdAt,
    this.files = const [],
  });

  factory Speaker.fromJson(Map<String, dynamic> json) {
    final filesList = json['files'] as List<dynamic>?;

    return Speaker(
      speakerId: json['speaker_id'] as String,
      name: json['name'] as String,
      totalDuration: (json['total_duration'] as num).toDouble(),
      fileCount: json['file_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      files: filesList != null
          ? filesList.map((file) => SpeakerFile.fromJson(file as Map<String, dynamic>)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speaker_id': speakerId,
      'name': name,
      'total_duration': totalDuration,
      'file_count': fileCount,
      'created_at': createdAt.toIso8601String(),
      'files': files.map((file) => file.toJson()).toList(),
    };
  }

  // Helper method to format duration
  String getFormattedDuration() {
    final hours = (totalDuration / 3600).floor();
    final minutes = ((totalDuration % 3600) / 60).floor();

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${totalDuration.floor()}s';
    }
  }
}
