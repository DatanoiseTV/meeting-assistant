import 'dart:convert';

class Meeting {
  final String id;
  final DateTime createdAt;
  final int? durationSeconds;
  final String? language;
  final String transcription;
  final String? title;
  final String? tagline;
  final String? summary;
  final String? participants;
  final String? tags;
  final String? topic;
  final String? keyTakeaways;
  final String? agendaItems;
  final String? discussionPoints;
  final String? questions;
  final String? decisions;
  final String? suggestions;
  final List<MeetingDate> dates;
  final List<ActionItem> actionItems;
  final String? graphData;
  final String? emailDraft;
  final bool isAnalyzed;
  final String? researchResults;
  final String? researchRecommendations;
  final String? researchComments;

  Meeting({
    required this.id,
    required this.createdAt,
    this.durationSeconds,
    this.language,
    required this.transcription,
    this.title,
    this.tagline,
    this.summary,
    this.participants,
    this.tags,
    this.topic,
    this.keyTakeaways,
    this.agendaItems,
    this.discussionPoints,
    this.questions,
    this.decisions,
    this.suggestions,
    this.dates = const [],
    this.actionItems = const [],
    this.graphData,
    this.emailDraft,
    this.isAnalyzed = false,
    this.researchResults,
    this.researchRecommendations,
    this.researchComments,
  });

  String get formattedDuration {
    if (durationSeconds == null) return '';
    final mins = durationSeconds! ~/ 60;
    final secs = durationSeconds! % 60;
    if (mins > 0) {
      return '${mins}m ${secs}s';
    }
    return '${secs}s';
  }

  Meeting copyWith({
    String? id,
    DateTime? createdAt,
    int? durationSeconds,
    String? language,
    String? transcription,
    String? title,
    String? tagline,
    String? summary,
    String? participants,
    String? tags,
    String? topic,
    String? keyTakeaways,
    String? agendaItems,
    String? discussionPoints,
    String? questions,
    String? decisions,
    String? suggestions,
    List<MeetingDate>? dates,
    List<ActionItem>? actionItems,
    String? graphData,
    String? emailDraft,
    bool? isAnalyzed,
    String? researchResults,
    String? researchRecommendations,
    String? researchComments,
  }) {
    return Meeting(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      language: language ?? this.language,
      transcription: transcription ?? this.transcription,
      title: title ?? this.title,
      tagline: tagline ?? this.tagline,
      summary: summary ?? this.summary,
      participants: participants ?? this.participants,
      tags: tags ?? this.tags,
      topic: topic ?? this.topic,
      keyTakeaways: keyTakeaways ?? this.keyTakeaways,
      agendaItems: agendaItems ?? this.agendaItems,
      discussionPoints: discussionPoints ?? this.discussionPoints,
      questions: questions ?? this.questions,
      decisions: decisions ?? this.decisions,
      suggestions: suggestions ?? this.suggestions,
      dates: dates ?? this.dates,
      actionItems: actionItems ?? this.actionItems,
      graphData: graphData ?? this.graphData,
      emailDraft: emailDraft ?? this.emailDraft,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
      researchResults: researchResults ?? this.researchResults,
      researchRecommendations:
          researchRecommendations ?? this.researchRecommendations,
      researchComments: researchComments ?? this.researchComments,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'language': language,
    'transcription': transcription,
    'title': title,
    'tagline': tagline,
    'summary': summary,
    'participants': participants,
    'tags': tags,
    'topic': topic,
    'keyTakeaways': keyTakeaways,
    'agendaItems': agendaItems,
    'discussionPoints': discussionPoints,
    'questions': questions,
    'decisions': decisions,
    'suggestions': suggestions,
    'dates': dates.map((e) => e.toJson()).toList(),
    'actionItems': actionItems.map((e) => e.toJson()).toList(),
    'graphData': graphData,
    'emailDraft': emailDraft,
    'isAnalyzed': isAnalyzed,
    'researchResults': researchResults,
    'researchRecommendations': researchRecommendations,
    'researchComments': researchComments,
  };

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
    id: json['id'],
    createdAt: DateTime.parse(json['createdAt']),
    durationSeconds: json['durationSeconds'],
    language: json['language'],
    transcription: json['transcription'],
    title: json['title'],
    tagline: json['tagline'],
    summary: json['summary'],
    participants: json['participants'],
    tags: json['tags'],
    topic: json['topic'],
    keyTakeaways: json['keyTakeaways'],
    agendaItems: json['agendaItems'],
    discussionPoints: json['discussionPoints'],
    questions: json['questions'],
    decisions: json['decisions'],
    suggestions: json['suggestions'],
    dates:
        (json['dates'] as List<dynamic>?)
            ?.map((e) => MeetingDate.fromJson(e))
            .toList() ??
        [],
    actionItems:
        (json['actionItems'] as List<dynamic>?)
            ?.map((e) => ActionItem.fromJson(e))
            .toList() ??
        [],
    graphData: json['graphData'],
    emailDraft: json['emailDraft'],
    isAnalyzed: json['isAnalyzed'] ?? false,
    researchResults: json['researchResults'],
    researchRecommendations: json['researchRecommendations'],
    researchComments: json['researchComments'],
  );
}

class MeetingDate {
  final String id;
  final String title;
  final DateTime dateTime;
  final String? description;

  MeetingDate({
    required this.id,
    required this.title,
    required this.dateTime,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateTime': dateTime.toIso8601String(),
    'description': description,
  };

  factory MeetingDate.fromJson(Map<String, dynamic> json) => MeetingDate(
    id: json['id'],
    title: json['title'],
    dateTime: DateTime.parse(json['dateTime']),
    description: json['description'],
  );
}

class ActionItem {
  final String id;
  final String text;
  final bool isCompleted;

  ActionItem({required this.id, required this.text, this.isCompleted = false});

  ActionItem copyWith({String? id, String? text, bool? isCompleted}) {
    return ActionItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isCompleted': isCompleted,
  };

  factory ActionItem.fromJson(Map<String, dynamic> json) => ActionItem(
    id: json['id'] ?? '',
    text: json['text'] ?? '',
    isCompleted: json['isCompleted'] ?? false,
  );
}

class ActionItemsHelper {
  static List<ActionItem> parseFromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      if (jsonString.trim().startsWith('[')) {
        final List<dynamic> items = jsonDecode(jsonString);
        return items.asMap().entries.map((e) {
          String text = e.value.toString();
          bool isCompleted = false;
          if (text.startsWith('[x]')) {
            isCompleted = true;
            text = text.substring(3).trim();
          } else if (text.startsWith('[ ]')) {
            text = text.substring(3).trim();
          }
          return ActionItem(
            id: e.key.toString(),
            text: text,
            isCompleted: isCompleted,
          );
        }).toList();
      }
    } catch (_) {}

    final items = <ActionItem>[];
    for (var i = 0; i < jsonString.split('\n').length; i++) {
      final line = jsonString.split('\n')[i].trim();
      if (line.isEmpty) continue;
      String text = line.replaceFirst(RegExp(r'^- ?'), '');
      bool isCompleted = text.contains('[x]');
      text = text.replaceAll(RegExp(r'^\[.?\] ?'), '');
      items.add(
        ActionItem(id: i.toString(), text: text, isCompleted: isCompleted),
      );
    }
    return items;
  }

  static List<String> parseListFromJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      if (jsonString.trim().startsWith('[')) {
        final List<dynamic> items = jsonDecode(jsonString);
        return items.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return jsonString
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }
}
