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

  const MeetingReport({
    required this.title,
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
    );
  }

  factory MeetingReport.fromJson(Map<String, dynamic> json) {
    return MeetingReport(
      title: json['title'] ?? '',
      overview: json['summary'] ?? '',
      participants: json['participants'] ?? '',
      tags: json['tags'] ?? '',
      topic: json['topic'] ?? '',
      summary: json['summary'] ?? '',
      keyTakeaways: json['keyTakeaways'] ?? '',
      agendaItems: json['agendaItems'] ?? '',
      discussionPoints: json['discussionPoints'] ?? '',
      questions: json['questions'] ?? '',
      decisions: json['decisions'] ?? '',
      suggestions: json['suggestions'] ?? '',
      actionItems: json['actionItems'] ?? '',
      dates: json['dates'] ?? '',
      graphData: json['graphData'] ?? '',
      emailDraft: json['emailDraft'] ?? '',
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

Generate the report with these exact section headers. For ACTION_ITEMS and SUGGESTIONS, output as a JSON array with one item per line: ["task 1", "task 2", "task 3"]. For GRAPH_DATA, use format: node1->node2;node2->node3;etc (semicolon separated directed edges showing meeting flow). For DATES, use format: date:YYYY-MM-DD|time:HH:MM|title:Event Title|desc:Optional description (one per line):
---PARTICIPANTS---
---TAGS---
---TITLE---
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
---EMAIL_DRAFT---''';
  }

  void reset() {
    state = const MeetingAnalysisState();
  }

  void loadStoredAnalysis({
    required String title,
    required String summary,
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
  }) {
    final report = MeetingReport(
      title: title,
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
    );
    state = MeetingAnalysisState(
      status: AnalysisStatus.completed,
      report: report,
    );
  }
}
