class Speaker {
  final String speakerId;
  final String name;
  final double totalDuration; // in seconds
  final int fileCount;
  final DateTime createdAt;

  Speaker({
    required this.speakerId,
    required this.name,
    required this.totalDuration,
    required this.fileCount,
    required this.createdAt,
  });

  factory Speaker.fromJson(Map<String, dynamic> json) {
    return Speaker(
      speakerId: json['speaker_id'] as String,
      name: json['name'] as String,
      totalDuration: (json['total_duration'] as num).toDouble(),
      fileCount: json['file_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speaker_id': speakerId,
      'name': name,
      'total_duration': totalDuration,
      'file_count': fileCount,
      'created_at': createdAt.toIso8601String(),
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
