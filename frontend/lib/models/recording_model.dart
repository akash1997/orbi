/// Model for speaker segment
class SpeakerSegment {
  final double start;
  final double end;
  final double duration;
  final String transcription;

  SpeakerSegment({
    required this.start,
    required this.end,
    required this.duration,
    required this.transcription,
  });

  factory SpeakerSegment.fromJson(Map<String, dynamic> json) {
    return SpeakerSegment(
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      transcription: json['transcription'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'duration': duration,
      'transcription': transcription,
    };
  }
}

/// Model for speaker insights
class SpeakerInsights {
  final String speakingStyle;
  final String sentiment;
  final double sentimentScore;
  final List<String> improvements;
  final int wordCount;
  final int fillerWordsCount;
  final double speakingPace;

  SpeakerInsights({
    required this.speakingStyle,
    required this.sentiment,
    required this.sentimentScore,
    required this.improvements,
    required this.wordCount,
    required this.fillerWordsCount,
    required this.speakingPace,
  });

  factory SpeakerInsights.fromJson(Map<String, dynamic> json) {
    return SpeakerInsights(
      speakingStyle: json['speaking_style'] as String,
      sentiment: json['sentiment'] as String,
      sentimentScore: (json['sentiment_score'] as num).toDouble(),
      improvements: (json['improvements'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      wordCount: json['word_count'] as int,
      fillerWordsCount: json['filler_words_count'] as int,
      speakingPace: (json['speaking_pace'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speaking_style': speakingStyle,
      'sentiment': sentiment,
      'sentiment_score': sentimentScore,
      'improvements': improvements,
      'word_count': wordCount,
      'filler_words_count': fillerWordsCount,
      'speaking_pace': speakingPace,
    };
  }
}

/// Model for speaker in a recording
class RecordingSpeaker {
  final String speakerId;
  final String name;
  final bool isNew;
  final double totalDuration;
  final int segmentCount;
  final List<SpeakerSegment> segments;
  final SpeakerInsights insights;

  RecordingSpeaker({
    required this.speakerId,
    required this.name,
    required this.isNew,
    required this.totalDuration,
    required this.segmentCount,
    required this.segments,
    required this.insights,
  });

  factory RecordingSpeaker.fromJson(Map<String, dynamic> json) {
    return RecordingSpeaker(
      speakerId: json['speaker_id'] as String,
      name: json['name'] as String,
      isNew: json['is_new'] as bool,
      totalDuration: (json['total_duration'] as num).toDouble(),
      segmentCount: json['segment_count'] as int,
      segments: (json['segments'] as List<dynamic>)
          .map((e) => SpeakerSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      insights: SpeakerInsights.fromJson(json['insights'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speaker_id': speakerId,
      'name': name,
      'is_new': isNew,
      'total_duration': totalDuration,
      'segment_count': segmentCount,
      'segments': segments.map((e) => e.toJson()).toList(),
      'insights': insights.toJson(),
    };
  }
}

/// Model for action item
class ActionItem {
  final String item;
  final String? assignedTo;
  final String mentionedBy;
  final String priority;

  ActionItem({
    required this.item,
    this.assignedTo,
    required this.mentionedBy,
    required this.priority,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      item: json['item'] as String,
      assignedTo: json['assigned_to'] as String?,
      mentionedBy: json['mentioned_by'] as String,
      priority: json['priority'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item': item,
      'assigned_to': assignedTo,
      'mentioned_by': mentionedBy,
      'priority': priority,
    };
  }
}

/// Model for meeting reminder
class MeetingReminder {
  final String type;
  final String description;
  final String? dateTime;
  final List<String> participants;

  MeetingReminder({
    required this.type,
    required this.description,
    this.dateTime,
    required this.participants,
  });

  factory MeetingReminder.fromJson(Map<String, dynamic> json) {
    return MeetingReminder(
      type: json['type'] as String,
      description: json['description'] as String,
      dateTime: json['date_time'] as String?,
      participants: (json['participants'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'date_time': dateTime,
      'participants': participants,
    };
  }
}

/// Model for conversation insights
class ConversationInsights {
  final String summary;
  final String sentiment;
  final double sentimentScore;
  final List<String> keyTopics;
  final List<ActionItem> actionItems;
  final List<MeetingReminder> meetingsReminders;

  ConversationInsights({
    required this.summary,
    required this.sentiment,
    required this.sentimentScore,
    required this.keyTopics,
    required this.actionItems,
    required this.meetingsReminders,
  });

  factory ConversationInsights.fromJson(Map<String, dynamic> json) {
    return ConversationInsights(
      summary: json['summary'] as String,
      sentiment: json['sentiment'] as String,
      sentimentScore: (json['sentiment_score'] as num).toDouble(),
      keyTopics: (json['key_topics'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      actionItems: (json['action_items'] as List<dynamic>)
          .map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      meetingsReminders: (json['meetings_reminders'] as List<dynamic>)
          .map((e) => MeetingReminder.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'sentiment': sentiment,
      'sentiment_score': sentimentScore,
      'key_topics': keyTopics,
      'action_items': actionItems.map((e) => e.toJson()).toList(),
      'meetings_reminders': meetingsReminders.map((e) => e.toJson()).toList(),
    };
  }
}

/// Model for recording detail from /recordings/{audio_file_id} endpoint
class RecordingDetail {
  final String audioFileId;
  final String filename;
  final double duration;
  final DateTime uploadedAt;
  final DateTime? processedAt;
  final String processingStatus;
  final int speakersDetected;
  final List<RecordingSpeaker> speakers;
  final ConversationInsights conversationInsights;

  RecordingDetail({
    required this.audioFileId,
    required this.filename,
    required this.duration,
    required this.uploadedAt,
    this.processedAt,
    required this.processingStatus,
    required this.speakersDetected,
    required this.speakers,
    required this.conversationInsights,
  });

  factory RecordingDetail.fromJson(Map<String, dynamic> json) {
    return RecordingDetail(
      audioFileId: json['audio_file_id'] as String,
      filename: json['filename'] as String,
      duration: (json['duration'] as num).toDouble(),
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
      processingStatus: json['processing_status'] as String,
      speakersDetected: json['speakers_detected'] as int,
      speakers: (json['speakers'] as List<dynamic>)
          .map((e) => RecordingSpeaker.fromJson(e as Map<String, dynamic>))
          .toList(),
      conversationInsights: ConversationInsights.fromJson(
          json['conversation_insights'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audio_file_id': audioFileId,
      'filename': filename,
      'duration': duration,
      'uploaded_at': uploadedAt.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'processing_status': processingStatus,
      'speakers_detected': speakersDetected,
      'speakers': speakers.map((e) => e.toJson()).toList(),
      'conversation_insights': conversationInsights.toJson(),
    };
  }
}
