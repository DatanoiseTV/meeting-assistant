import 'dart:convert';
import 'package:http/http.dart' as http;

class LLMResponse {
  final String text;
  final Map<String, dynamic>? json;
  final bool isError;
  final String? error;
  final int? retryAfter;

  LLMResponse({
    required this.text,
    this.json,
    this.isError = false,
    this.error,
    this.retryAfter,
  });
}

class QuotaInfo {
  final int requestsLimit;
  final int requestsUsed;
  final int tokensLimit;
  final int tokensUsed;
  final String? error;

  QuotaInfo({
    required this.requestsLimit,
    required this.requestsUsed,
    required this.tokensLimit,
    required this.tokensUsed,
    this.error,
  });

  double get requestsPercent =>
      requestsLimit > 0 ? (requestsUsed / requestsLimit) * 100 : 0;
  double get tokensPercent =>
      tokensLimit > 0 ? (tokensUsed / tokensLimit) * 100 : 0;
  bool get isNearLimit => requestsPercent > 80 || tokensPercent > 80;
}

class LLMService {
  final String apiKey;
  final String model;

  static const int maxRetries = 1;
  static const int initialRetryDelayMs = 2000;

  static const List<String> flashModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
  ];

  static const String _researchSystemPrompt =
      '''You are a research assistant that analyzes meeting topics and provides valuable insights based on current information from the web.

IMPORTANT: NEVER use dash "-" or bullet points "*" for lists. Only use JSON arrays.
All list fields must be proper JSON arrays like ["item1", "item2"] - never use:
- "- item"
- "* item"  
- "1. item"

When given a meeting transcript or summary, you will:
1. Identify key topics and concepts discussed
2. Research those topics using web search
3. Provide actionable recommendations, comments, and suggestions based on your research

OUTPUT FORMAT REQUIREMENTS:
- Keep descriptions concise but informative
- Base your recommendations on verified information from web searches
- If no information available, write "Unable to research"

JSON STRUCTURE:
All fields should be strings or arrays of strings.''';

  static const String _researchJsonSchema = '''
{
  "type": "object",
  "properties": {
    "researchResults": {"type": "string", "description": "Summary of research findings from web search"},
    "researchRecommendations": {"type": "array", "items": {"type": "string"}, "description": "Array of actionable recommendations based on research"},
    "researchComments": {"type": "string", "description": "Additional insights and comments"}
  },
  "required": ["researchResults", "researchRecommendations"]
}
''';

  LLMService({required this.apiKey, required this.model});

  static const String _systemPrompt =
      '''You are a professional meeting assistant that analyzes transcriptions and creates structured summaries. 

IMPORTANT: NEVER use dash "-" or bullet points "*" for lists. Only use JSON arrays.
All list fields must be proper JSON arrays like ["item1", "item2"] - never use:
- "- item"
- "* item"  
- "1. item"

OUTPUT FORMAT REQUIREMENTS:
- Keep descriptions concise but informative
- If no information available, write "None recorded" (not N/A, none, etc.)

JSON STRUCTURE:
All fields should be strings.''';

  static const String _jsonSchema = '''
{
  "type": "object",
  "properties": {
    "participants": {"type": "array", "items": {"type": "string"}, "description": "Array of participants"},
    "tags": {"type": "array", "items": {"type": "string"}, "description": "Array of tags"},
    "title": {"type": "string", "description": "Short title for the meeting"},
    "tagline": {"type": "string", "description": "Very short one-line summary (max 10 words)"},
    "topic": {"type": "string", "description": "Main topic of the meeting"},
    "summary": {"type": "string", "description": "Brief paragraph summary"},
    "keyTakeaways": {"type": "array", "items": {"type": "string"}, "minItems": 1, "description": "Array of key insights"},
    "agendaItems": {"type": "array", "items": {"type": "string"}, "description": "Array of agenda items"},
    "discussionPoints": {"type": "array", "items": {"type": "string"}, "description": "Array of discussion points"},
    "questions": {"type": "array", "items": {"type": "string"}, "description": "Array of questions raised"},
    "decisions": {"type": "array", "items": {"type": "string"}, "description": "Array of decisions made"},
    "actionItems": {"type": "array", "items": {"type": "string"}, "minItems": 1, "description": "Array of action items/tasks"},
    "suggestions": {"type": "array", "items": {"type": "string"}, "description": "Array of suggestions"},
    "dates": {"type": "string", "description": "date:YYYY-MM-DD|time:HH:MM|title:Event|desc:Description format, one per line"},
    "graphData": {"type": "string", "description": "Directed edges: node1->node2;node2->node3 (semicolon separated)"},
    "emailDraft": {"type": "string", "description": "Professional email draft"},
    "researchResults": {"type": "string", "description": "Summary of research findings from web search"},
    "researchRecommendations": {"type": "array", "items": {"type": "string"}, "description": "Array of actionable recommendations based on research"},
    "researchComments": {"type": "string", "description": "Additional insights and comments"}
  },
  "required": ["title", "tagline", "summary", "actionItems"]
}
''';

  static Future<List<String>> fetchAvailableModels(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List<dynamic>?;

        if (models == null) return flashModels;

        final availableFlash = models
            .map((m) => m['name'] as String)
            .where(
              (name) =>
                  name.contains('flash') &&
                  !name.contains('image') &&
                  !name.contains('tts') &&
                  !name.contains('preview-'),
            )
            .map((name) => name.replaceFirst('models/', ''))
            .toList();

        if (availableFlash.isEmpty) return flashModels;

        availableFlash.sort((a, b) {
          final order = [
            '2.5-flash',
            '2.0-flash',
            'flash-latest',
            'flash-lite',
          ];
          for (final o in order) {
            if (a.contains(o) && !b.contains(o)) return -1;
            if (!a.contains(o) && b.contains(o)) return 1;
          }
          return a.compareTo(b);
        });

        return availableFlash;
      }
    } catch (e) {
      print('Failed to fetch models: $e');
    }
    return flashModels;
  }

  Future<LLMResponse> generateSummary(String prompt) async {
    final modelsToTry = <String>{model, ...flashModels}.toList();

    for (int i = 0; i < modelsToTry.length; i++) {
      final currentModel = modelsToTry[i];
      print('Trying model: $currentModel');

      final response = await _generateWithSingleModel(
        prompt,
        currentModel,
        maxRetries,
      );

      if (!response.isError) {
        print('Success with model: $currentModel');
        return response;
      }

      final errorLower = response.error?.toLowerCase() ?? '';
      final isQuotaError =
          errorLower.contains('quota') ||
          errorLower.contains('rate limit') ||
          errorLower.contains('resource_exhausted') ||
          errorLower.contains('too many requests') ||
          errorLower.contains('unavailable');

      if (isQuotaError) {
        print('Quota/rate limit with $currentModel, trying next...');
        if (i < modelsToTry.length - 1) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
      }

      if (i == modelsToTry.length - 1) {
        return response;
      }
    }

    return LLMResponse(
      text: '',
      isError: true,
      error: 'AI capacity reached. Please try again in a few minutes.',
    );
  }

  Future<LLMResponse> _generateWithSingleModel(
    String prompt,
    String modelName,
    int retries,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': _systemPrompt},
            ],
          },
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 16384,
            'responseJsonSchema': jsonDecode(_jsonSchema),
            'responseMimeType': 'application/json',
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final jsonText = data['candidates'][0]['content']['parts'][0]['text'];
        final parsed = jsonDecode(jsonText);
        return LLMResponse(text: _formatAsText(parsed), json: parsed);
      } else if ((response.statusCode == 503 || response.statusCode == 429) &&
          retries > 0) {
        print('Rate limited with $modelName, retrying...');
        await Future.delayed(
          Duration(
            milliseconds: initialRetryDelayMs * (maxRetries - retries + 1),
          ),
        );
        return _generateWithSingleModel(prompt, modelName, retries - 1);
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error']?['message'] ?? 'Unknown error';
        final status = errorData['error']?['status'] ?? '';

        String friendlyMessage;
        if (status == 'RESOURCE_EXHAUSTED' || response.statusCode == 429) {
          friendlyMessage = 'Quota exceeded. Trying next model...';
        } else if (response.statusCode == 503) {
          friendlyMessage = 'Service temporarily unavailable.';
        } else {
          friendlyMessage = errorMsg;
        }

        return LLMResponse(text: '', isError: true, error: friendlyMessage);
      }
    } catch (e) {
      if (retries > 0 && e.toString().contains('SocketException')) {
        await Future.delayed(Duration(milliseconds: initialRetryDelayMs));
        return _generateWithSingleModel(prompt, modelName, retries - 1);
      }
      return LLMResponse(text: '', isError: true, error: e.toString());
    }
  }

  String _formatAsText(Map<String, dynamic> json) {
    return '''---PARTICIPANTS---
${json['participants'] ?? ''}

---TAGS---
${json['tags'] ?? ''}

---TITLE---
${json['title'] ?? ''}

---TOPIC---
${json['topic'] ?? ''}

---YAML_SUMMARY---
${json['summary'] ?? ''}

---OVERVIEW_SUMMARY---
${json['summary'] ?? ''}

---KEY_TAKEAWAYS---
${json['keyTakeaways'] ?? ''}

---AGENDA_ITEMS---
${json['agendaItems'] ?? ''}

---DISCUSSION_POINTS---
${json['discussionPoints'] ?? ''}

---QUESTIONS_ARISEN---
${json['questions'] ?? ''}

---DECISIONS_MADE---
${json['decisions'] ?? ''}

---ACTION_ITEMS---
${json['actionItems'] ?? ''}

---GRAPH_DATA---
${json['graphData'] ?? ''}

---EMAIL_DRAFT---
${json['emailDraft'] ?? ''}

---RESEARCH_RESULTS---
${json['researchResults'] ?? ''}

---RESEARCH_RECOMMENDATIONS---
${json['researchRecommendations'] ?? ''}

---RESEARCH_COMMENTS---
${json['researchComments'] ?? ''}''';
  }

  Future<LLMResponse> generateResearch(String prompt) async {
    final modelsToTry = <String>{model, ...flashModels}.toList();

    for (int i = 0; i < modelsToTry.length; i++) {
      final currentModel = modelsToTry[i];
      print('Trying research model: $currentModel');

      final response = await _generateResearchWithModel(
        prompt,
        currentModel,
        maxRetries,
      );

      if (!response.isError) {
        print('Research success with model: $currentModel');
        return response;
      }

      final errorLower = response.error?.toLowerCase() ?? '';
      final isQuotaError =
          errorLower.contains('quota') ||
          errorLower.contains('rate limit') ||
          errorLower.contains('resource_exhausted') ||
          errorLower.contains('too many requests') ||
          errorLower.contains('unavailable');

      if (isQuotaError) {
        print('Quota/rate limit with $currentModel, trying next...');
        if (i < modelsToTry.length - 1) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
      }

      if (i == modelsToTry.length - 1) {
        return response;
      }
    }

    return LLMResponse(
      text: '',
      isError: true,
      error: 'AI capacity reached. Please try again in a few minutes.',
    );
  }

  Future<LLMResponse> _generateResearchWithModel(
    String prompt,
    String modelName,
    int retries,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': _researchSystemPrompt},
            ],
          },
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'tools': [
            {'googleSearch': {}},
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 8192,
            'responseJsonSchema': jsonDecode(_researchJsonSchema),
            'responseMimeType': 'application/json',
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] == null || data['candidates'].isEmpty) {
          return LLMResponse(
            text: '',
            isError: true,
            error: 'No response from model',
          );
        }

        final candidate = data['candidates'][0];

        if (candidate['content'] == null) {
          return LLMResponse(
            text: '',
            isError: true,
            error: 'No content in response',
          );
        }

        final jsonText = candidate['content']['parts'][0]['text'];
        final parsed = jsonDecode(jsonText);
        return LLMResponse(text: _formatAsText(parsed), json: parsed);
      } else if ((response.statusCode == 503 || response.statusCode == 429) &&
          retries > 0) {
        print('Rate limited with $modelName, retrying research...');
        await Future.delayed(
          Duration(
            milliseconds: initialRetryDelayMs * (maxRetries - retries + 1),
          ),
        );
        return _generateResearchWithModel(prompt, modelName, retries - 1);
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error']?['message'] ?? 'Unknown error';
        final status = errorData['error']?['status'] ?? '';

        String friendlyMessage;
        if (status == 'RESOURCE_EXHAUSTED' || response.statusCode == 429) {
          friendlyMessage = 'Quota exceeded. Trying next model...';
        } else if (response.statusCode == 503) {
          friendlyMessage = 'Service temporarily unavailable.';
        } else {
          friendlyMessage = errorMsg;
        }

        return LLMResponse(text: '', isError: true, error: friendlyMessage);
      }
    } catch (e) {
      if (retries > 0 && e.toString().contains('SocketException')) {
        await Future.delayed(Duration(milliseconds: initialRetryDelayMs));
        return _generateResearchWithModel(prompt, modelName, retries - 1);
      }
      return LLMResponse(text: '', isError: true, error: e.toString());
    }
  }
}
