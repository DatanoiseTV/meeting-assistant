import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/repositories/llm_service.dart';

final llmServiceProvider = Provider<LLMService?>((ref) {
  final settings = ref.watch(settingsProvider);

  return settings.when(
    data: (config) {
      if (config.apiKey.isEmpty || config.llmModel.isEmpty) {
        return null;
      }

      final llmService = LLMService(
        apiKey: config.apiKey,
        model: config.llmModel,
        customUrl: config.customApiUrl,
      );

      print('LLM Service Configured: Model=${config.llmModel}');

      return llmService;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

final meetingAnalysisProvider =
    StateNotifierProvider<MeetingAnalysisNotifier, MeetingAnalysisState>((ref) {
      final llmService = ref.watch(llmServiceProvider);
      final settingsAsyncValue = ref.watch(settingsProvider);

      String persona = 'general';
      settingsAsyncValue.whenData((config) {
        persona = config.persona;
      });

      // Log when checking for service availability
      print(
        'MeetingAnalysisProvider initialized. LLM Service available: ${llmService != null}, Persona: $persona',
      );

      return MeetingAnalysisNotifier(llmService, persona);
    });

// Enum for analysis status
enum AnalysisStatus { idle, analyzing, completed, error }

class MeetingAnalysisState {
  final AnalysisStatus status;
  final MeetingReport? report;
  final String? errorMessage;

  const MeetingAnalysisState({
    this.status = AnalysisStatus.idle,
    this.report,
    this.errorMessage,
  });

  MeetingAnalysisState copyWith({
    AnalysisStatus? status,
    MeetingReport? report,
    String? errorMessage,
  }) {
    return MeetingAnalysisState(
      status: status ?? this.status,
      report: report ?? this.report,
      errorMessage: errorMessage,
    );
  }
}

class MeetingReport {
  final String title;
  final String tagline;
  final String overview;
  final String participants;
  final String tags;
  final String topic;
  final String summary;
  final String keyTakeaways;
  final String agendaItems;
  final String discussionPoints;
  final String questions;
  final String decisions;
  final String suggestions;
  final String actionItems;
  final String dates;
  final String graphData;
  final String emailDraft;
  final String researchResults;
  final String researchRecommendations;
  final String researchComments;

  const MeetingReport({
    required this.title,
    required this.tagline,
    required this.overview,
    required this.participants,
    required this.tags,
    required this.topic,
    required this.summary,
    required this.keyTakeaways,
    required this.agendaItems,
    required this.discussionPoints,
    required this.questions,
    required this.decisions,
    required this.suggestions,
    required this.actionItems,
    required this.dates,
    required this.graphData,
    required this.emailDraft,
    this.researchResults = '',
    this.researchRecommendations = '',
    this.researchComments = '',
  });

  List<GraphEdge> get graphEdges {
    if (graphData.isEmpty) return [];
    return graphData
        .split(';')
        .map((e) {
          final parts = e.split('->');
          if (parts.length == 2) {
            return GraphEdge(from: parts[0].trim(), to: parts[1].trim());
          }
          return null;
        })
        .whereType<GraphEdge>()
        .toList();
  }

  Set<String> get graphNodes {
    final nodes = <String>{};
    for (final edge in graphEdges) {
      nodes.add(edge.from);
      nodes.add(edge.to);
    }
    return nodes;
  }

  List<Suggestion> get suggestionList {
    if (suggestions.isEmpty) return [];

    // Try JSON array format first: ["item1", "item2"]
    if (suggestions.trim().startsWith('[')) {
      try {
        final List<dynamic> items = _parseJsonArray(suggestions);
        return items
            .asMap()
            .entries
            .map(
              (e) => Suggestion(id: e.key.toString(), text: e.value.toString()),
            )
            .toList();
      } catch (_) {}
    }

    // Fallback to line-by-line
    return suggestions
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map(
          (l) => Suggestion(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: l
                .replaceFirst(RegExp(r'^- ?'), '')
                .replaceAll(RegExp(r'^\["|"\]|"$'), ''),
          ),
        )
        .toList();
  }

  List<String> get actionItemsList {
    if (actionItems.isEmpty) return [];

    // Try JSON array format first: ["item1", "item2"]
    if (actionItems.trim().startsWith('[')) {
      try {
        final List<dynamic> items = _parseJsonArray(actionItems);
        return items.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    // Fallback to line-by-line
    return actionItems
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map(
          (l) => l
              .replaceFirst(RegExp(r'^- ?'), '')
              .replaceAll(RegExp(r'^\["|"\]|"$'), ''),
        )
        .toList();
  }

  List<dynamic> _parseJsonArray(String text) {
    // Simple JSON array parser
    final cleaned = text.trim();
    if (!cleaned.startsWith('[') || !cleaned.endsWith(']')) {
      throw FormatException('Not a JSON array');
    }
    final inner = cleaned.substring(1, cleaned.length - 1);
    final result = <String>[];
    var current = StringBuffer();
    var inQuote = false;
    var escape = false;

    for (var i = 0; i < inner.length; i++) {
      final c = inner[i];
      if (escape) {
        current.write(c);
        escape = false;
      } else if (c == '\\') {
        escape = true;
      } else if (c == '"') {
        inQuote = !inQuote;
      } else if (c == ',' && !inQuote) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(c);
      }
    }
    if (current.isNotEmpty) {
      result.add(current.toString().trim());
    }
    return result;
  }

  List<ParsedDate> get parsedDates {
    if (dates.isEmpty) return [];
    final result = <ParsedDate>[];
    for (final line in dates.split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        String? title;
        DateTime? dateTime;
        String? description;

        final titleMatch = RegExp(r'title:([^|]+)').firstMatch(line);
        if (titleMatch != null) title = titleMatch.group(1)?.trim();

        final descMatch = RegExp(r'desc:([^|]+)').firstMatch(line);
        if (descMatch != null) description = descMatch.group(1)?.trim();

        final dateMatch = RegExp(r'date:(\d{4}-\d{2}-\d{2})').firstMatch(line);
        final timeMatch = RegExp(r'time:(\d{2}:\d{2})').firstMatch(line);

        if (dateMatch != null) {
          final dateStr = dateMatch.group(1)!;
          final timeStr = timeMatch?.group(1) ?? '00:00';
          dateTime = DateTime.parse('${dateStr}T$timeStr:00');
        }

        if (title != null && dateTime != null) {
          result.add(
            ParsedDate(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              dateTime: dateTime,
              description: description,
            ),
          );
        }
      } catch (_) {}
    }
    return result;
  }

  factory MeetingReport.parse(String rawOutput) {
    String extract(String key) {
      final regex = RegExp('---$key---([\\s\\S]*?)(?=---|\$)', multiLine: true);
      final match = regex.firstMatch(rawOutput);
      if (match == null) return '';
      return match.group(1)?.trim() ?? '';
    }

    return MeetingReport(
      title: extract('TITLE'),
      tagline: extract('TAGLINE'),
      overview: extract('OVERVIEW_SUMMARY'),
      participants: extract('PARTICIPANTS'),
      tags: extract('TAGS'),
      topic: extract('TOPIC'),
      summary: extract('YAML_SUMMARY'),
      keyTakeaways: extract('KEY_TAKEAWAYS'),
      agendaItems: extract('AGENDA_ITEMS'),
      discussionPoints: extract('DISCUSSION_POINTS'),
      questions: extract('QUESTIONS_ARISEN'),
      decisions: extract('DECISIONS_MADE'),
      suggestions: extract('SUGGESTIONS'),
      actionItems: extract('ACTION_ITEMS'),
      dates: extract('DATES'),
      graphData: extract('GRAPH_DATA'),
      emailDraft: extract('EMAIL_DRAFT'),
      researchResults: extract('RESEARCH_RESULTS'),
      researchRecommendations: extract('RESEARCH_RECOMMENDATIONS'),
      researchComments: extract('RESEARCH_COMMENTS'),
    );
  }

  factory MeetingReport.fromJson(Map<String, dynamic> json) {
    String _toString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is List)
        return value.map((e) => e.toString()).toList().toString();
      return value.toString();
    }

    String _listToJsonString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is List)
        return jsonEncode(value.map((e) => e.toString()).toList());
      return value.toString();
    }

    return MeetingReport(
      title: _toString(json['title']),
      tagline: _toString(json['tagline']),
      overview: _toString(json['summary']),
      participants: _toString(json['participants']),
      tags: _listToJsonString(json['tags']),
      topic: _toString(json['topic']),
      summary: _toString(json['summary']),
      keyTakeaways: _listToJsonString(json['keyTakeaways']),
      agendaItems: _listToJsonString(json['agendaItems']),
      discussionPoints: _listToJsonString(json['discussionPoints']),
      questions: _listToJsonString(json['questions']),
      decisions: _listToJsonString(json['decisions']),
      suggestions: _listToJsonString(json['suggestions']),
      actionItems: _listToJsonString(json['actionItems']),
      dates: _toString(json['dates']),
      graphData: _toString(json['graphData']),
      emailDraft: _toString(json['emailDraft']),
      researchResults: _toString(json['researchResults']),
      researchRecommendations: _listToJsonString(
        json['researchRecommendations'],
      ),
      researchComments: _toString(json['researchComments']),
    );
  }
}

class Suggestion {
  final String id;
  final String text;
  bool isAccepted;
  Suggestion({required this.id, required this.text, this.isAccepted = false});
}

class ParsedDate {
  final String id;
  final String title;
  final DateTime dateTime;
  final String? description;
  ParsedDate({
    required this.id,
    required this.title,
    required this.dateTime,
    this.description,
  });
}

class GraphEdge {
  final String from;
  final String to;
  GraphEdge({required this.from, required this.to});
}

class MeetingAnalysisNotifier extends StateNotifier<MeetingAnalysisState> {
  final LLMService? _llmService;
  final String _persona;

  MeetingAnalysisNotifier(this._llmService, this._persona)
    : super(const MeetingAnalysisState());

  Future<void> analyzeMeeting(String transcription) async {
    if (_llmService == null) {
      state = state.copyWith(
        status: AnalysisStatus.error,
        errorMessage:
            'Please configure LLM in Settings (provider, API key, model)',
      );
      return;
    }

    try {
      state = state.copyWith(status: AnalysisStatus.analyzing);

      final prompt = _buildAnalysisPrompt(transcription, _persona);
      final response = await _llmService.generateSummary(prompt);

      if (response.isError) {
        state = state.copyWith(
          status: AnalysisStatus.error,
          errorMessage: response.error,
        );
      } else {
        print(
          'Parsed report - title: ${response.json?['title']}, summary: ${response.json?['summary']}',
        );

        if (response.json != null) {
          final report = MeetingReport.fromJson(response.json!);
          state = state.copyWith(
            status: AnalysisStatus.completed,
            report: report,
          );
        } else {
          final report = MeetingReport.parse(response.text);
          state = state.copyWith(
            status: AnalysisStatus.completed,
            report: report,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        status: AnalysisStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> researchTopics(
    String transcription, {
    MeetingReport? existingReport,
  }) async {
    if (_llmService == null) {
      state = state.copyWith(
        status: AnalysisStatus.error,
        errorMessage:
            'Please configure LLM in Settings (provider, API key, model)',
      );
      return;
    }

    try {
      state = state.copyWith(status: AnalysisStatus.analyzing);

      final prompt = _buildResearchPrompt(transcription);
      final response = await _llmService.generateResearch(prompt);

      if (response.isError) {
        state = state.copyWith(
          status: AnalysisStatus.error,
          errorMessage: response.error,
        );
      } else {
        MeetingReport finalReport;

        if (response.json != null) {
          final newResearch = MeetingReport.fromJson(response.json!);
          finalReport = MeetingReport(
            title: existingReport?.title ?? newResearch.title,
            tagline: existingReport?.tagline ?? newResearch.tagline,
            overview: existingReport?.overview ?? newResearch.overview,
            participants:
                existingReport?.participants ?? newResearch.participants,
            tags: existingReport?.tags ?? newResearch.tags,
            topic: existingReport?.topic ?? newResearch.topic,
            summary: existingReport?.summary ?? newResearch.summary,
            keyTakeaways:
                existingReport?.keyTakeaways ?? newResearch.keyTakeaways,
            agendaItems: existingReport?.agendaItems ?? newResearch.agendaItems,
            discussionPoints:
                existingReport?.discussionPoints ??
                newResearch.discussionPoints,
            questions: existingReport?.questions ?? newResearch.questions,
            decisions: existingReport?.decisions ?? newResearch.decisions,
            suggestions: existingReport?.suggestions ?? newResearch.suggestions,
            actionItems: existingReport?.actionItems ?? newResearch.actionItems,
            dates: existingReport?.dates ?? newResearch.dates,
            graphData: existingReport?.graphData ?? newResearch.graphData,
            emailDraft: existingReport?.emailDraft ?? newResearch.emailDraft,
            researchResults: newResearch.researchResults,
            researchRecommendations: newResearch.researchRecommendations,
            researchComments: newResearch.researchComments,
          );
        } else {
          final parsed = MeetingReport.parse(response.text);
          finalReport = MeetingReport(
            title: existingReport?.title ?? parsed.title,
            tagline: existingReport?.tagline ?? parsed.tagline,
            overview: existingReport?.overview ?? parsed.overview,
            participants: existingReport?.participants ?? parsed.participants,
            tags: existingReport?.tags ?? parsed.tags,
            topic: existingReport?.topic ?? parsed.topic,
            summary: existingReport?.summary ?? parsed.summary,
            keyTakeaways: existingReport?.keyTakeaways ?? parsed.keyTakeaways,
            agendaItems: existingReport?.agendaItems ?? parsed.agendaItems,
            discussionPoints:
                existingReport?.discussionPoints ?? parsed.discussionPoints,
            questions: existingReport?.questions ?? parsed.questions,
            decisions: existingReport?.decisions ?? parsed.decisions,
            suggestions: existingReport?.suggestions ?? parsed.suggestions,
            actionItems: existingReport?.actionItems ?? parsed.actionItems,
            dates: existingReport?.dates ?? parsed.dates,
            graphData: existingReport?.graphData ?? parsed.graphData,
            emailDraft: existingReport?.emailDraft ?? parsed.emailDraft,
            researchResults: parsed.researchResults,
            researchRecommendations: parsed.researchRecommendations,
            researchComments: parsed.researchComments,
          );
        }

        state = state.copyWith(
          status: AnalysisStatus.completed,
          report: finalReport,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AnalysisStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  String _buildAnalysisPrompt(String transcription, String persona) {
    String personaInstructions;
    switch (persona.toLowerCase()) {
      case 'dev':
        personaInstructions =
            'Focus on architecture, technical trade-offs, code patterns, and technical debt.';
      case 'pm':
        personaInstructions =
            'Focus on deliverables, blockers, timelines, and accountability.';
      case 'exec':
        personaInstructions =
            'Focus on high-level strategic impact, budget, and ROI.';
      default:
        personaInstructions = 'Provide a balanced, general-purpose summary.';
    }

    return '''$personaInstructions

Please analyze the following meeting transcription and provide a structured report:

$transcription

OUTPUT FORMAT REQUIREMENTS:
- ACTION_ITEMS: plain text JSON array only, NO checkboxes, NO [x] or [ ]. Example: ["Complete code review", "Send email"]
- SUGGESTIONS: JSON array only. Example: ["Consider using async", "Add tests"]
- KEY_TAKEAWAYS: JSON array only. Example: ["First insight", "Second insight"]
- DECISIONS: JSON array only. Example: ["Approved budget", "Postponed launch"]
- QUESTIONS: JSON array only. Example: ["Question 1", "Question 2"]
- TAGS: lowercase_with_underscores, no spaces. Example: ["product_launch", "team_meeting", "q4_planning"]
- TAGLINE: One line only, max 10 words

GRAPH_DATA: node1->node2;node2->node3 (semicolon separated)
DATES: date:YYYY-MM-DD|time:HH:MM|title:Event|desc:Description (one per line)

---PARTICIPANTS---
---TAGS---
---TITLE---
---TAGLINE---
---TOPIC---
---YAML_SUMMARY---
---OVERVIEW_SUMMARY---
---KEY_TAKEAWAYS---
---AGENDA_ITEMS---
---DISCUSSION_POINTS---
---QUESTIONS_ARISEN---
---DECISIONS_MADE---
---SUGGESTIONS---
---ACTION_ITEMS---
---DATES---
---GRAPH_DATA---
---EMAIL_DRAFT---
---RESEARCH_RESULTS---
---RESEARCH_RECOMMENDATIONS---
---RESEARCH_COMMENTS---''';
  }

  String _buildResearchPrompt(String transcription) {
    return '''Please research the key topics discussed in the following meeting transcript and provide actionable recommendations based on current information from the web:

$transcription

Use Google Search to find relevant, up-to-date information on the topics discussed. Based on your research:
1. Summarize what you found (RESEARCH_RESULTS)
2. Provide actionable recommendations based on your findings (RESEARCH_RECOMMENDATIONS - JSON array)
3. Add any additional insights or comments (RESEARCH_COMMENTS)

IMPORTANT: Use JSON arrays for all list fields. Never use dashes or bullets.''';
  }

  void reset() {
    state = const MeetingAnalysisState();
  }

  void loadStoredAnalysis({
    required String title,
    required String summary,
    required String tagline,
    required String actionItems,
    required String decisions,
    required String keyTakeaways,
    required String topic,
    required String tags,
    required String participants,
    required String suggestions,
    required String dates,
    required String graphData,
    required String emailDraft,
    required String questions,
    required String discussionPoints,
    String researchResults = '',
    String researchRecommendations = '',
    String researchComments = '',
  }) {
    final report = MeetingReport(
      title: title,
      tagline: tagline,
      overview: summary,
      participants: participants,
      tags: tags,
      topic: topic,
      summary: summary,
      keyTakeaways: keyTakeaways,
      agendaItems: '',
      discussionPoints: discussionPoints,
      questions: questions,
      decisions: decisions,
      suggestions: suggestions,
      actionItems: actionItems,
      dates: dates,
      graphData: graphData,
      emailDraft: emailDraft,
      researchResults: researchResults,
      researchRecommendations: researchRecommendations,
      researchComments: researchComments,
    );
    state = MeetingAnalysisState(
      status: AnalysisStatus.completed,
      report: report,
    );
  }
}
