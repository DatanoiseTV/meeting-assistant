import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../llm/presentation/providers/llm_provider.dart';
import '../providers/providers.dart';
import '../providers/meetings_provider.dart';
import '../widgets/record_button.dart';
import '../widgets/transcription_view.dart';
import '../../domain/entities/meeting.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  String? _lastRecordingId;

  @override
  Widget build(BuildContext context) {
    final transcriptionState = ref.watch(transcriptionProvider);

    // Auto-save meeting when recording completes
    ref.listen(transcriptionProvider, (previous, next) {
      if (previous?.status != TranscriptionStatus.completed &&
          next.status == TranscriptionStatus.completed &&
          next.transcription.isNotEmpty) {
        _saveMeeting(next.transcription);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildRecordView(context),
            _buildMeetingsListView(context),
            _buildTodosView(context),
            const SettingsScreenContent(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible:
                  transcriptionState.status == TranscriptionStatus.completed,
              child: const Icon(Icons.mic_outlined),
            ),
            selectedIcon: const Icon(Icons.mic),
            label: 'Record',
          ),
          const NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Meetings',
          ),
          const NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Todos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _saveMeeting(String transcription) async {
    final settings = ref.read(settingsProvider).value;
    final language = settings?.speechLanguage ?? 'en_US';

    final meeting = Meeting(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      transcription: transcription,
      language: language,
    );

    await ref.read(meetingsProvider.notifier).addMeeting(meeting);
    setState(() => _lastRecordingId = meeting.id);
  }

  Widget _buildRecordView(BuildContext context) {
    final transcriptionState = ref.watch(transcriptionProvider);
    final isCompleted =
        transcriptionState.status == TranscriptionStatus.completed;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'Meeting Assistant',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Record your meetings and get AI-powered insights',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          RecordButton(state: transcriptionState),
          const SizedBox(height: 24),
          _buildStatusText(context, transcriptionState),
          const SizedBox(height: 16),
          if (isCompleted) ...[
            FilledButton.icon(
              onPressed: () {
                ref.read(transcriptionProvider.notifier).reset();
                setState(() => _selectedIndex = 1);
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View Meeting'),
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildStatusText(BuildContext context, TranscriptionState state) {
    String text;
    Color color;
    switch (state.status) {
      case TranscriptionStatus.idle:
        text = 'Tap to start recording';
        color = Colors.grey;
      case TranscriptionStatus.recording:
        text = 'Listening...';
        color = Colors.red;
      case TranscriptionStatus.processing:
        text = 'Initializing...';
        color = Colors.orange;
      case TranscriptionStatus.transcribing:
        text = 'Processing...';
        color = Colors.blue;
      case TranscriptionStatus.completed:
        text = 'Recording complete!';
        color = Colors.green;
      case TranscriptionStatus.error:
        text = state.errorMessage ?? 'Error occurred';
        color = Colors.red;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state.status == TranscriptionStatus.recording) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingsListView(BuildContext context) {
    final meetings = ref.watch(meetingsProvider);

    if (meetings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No meetings yet',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'Record your first meeting to see it here',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        final dateFormat = DateFormat('MMM d, yyyy');
        final timeFormat = DateFormat('h:mm a');

        return _MeetingListItem(
          meeting: meeting,
          dateFormat: dateFormat,
          timeFormat: timeFormat,
          onTap: () => _openMeeting(context, meeting),
          onDelete: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Meeting'),
                content: const Text(
                  'Are you sure you want to delete this meeting?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              ref.read(meetingsProvider.notifier).deleteMeeting(meeting.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Meeting deleted')),
                );
              }
            }
          },
        );
      },
    );
  }

  Widget _buildTodosView(BuildContext context) {
    final meetings = ref.watch(meetingsProvider);
    final allTodos = <_CombinedTodo>[];

    for (final meeting in meetings) {
      for (final item in meeting.actionItems) {
        allTodos.add(
          _CombinedTodo(
            meetingTitle: meeting.title ?? 'Untitled Meeting',
            meetingId: meeting.id,
            actionItem: item,
          ),
        );
      }
    }

    if (allTodos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.checklist, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No todos yet',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'Analyze meetings to extract action items',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allTodos.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Text(
                  'All Todos',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${allTodos.length} items',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final todo = allTodos[index - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Checkbox(
              value: todo.actionItem.isCompleted,
              onChanged: (value) async {
                final updatedItem = todo.actionItem.copyWith(
                  isCompleted: value ?? false,
                );
                final meetingIndex = meetings.indexWhere(
                  (m) => m.id == todo.meetingId,
                );
                if (meetingIndex != -1) {
                  final meeting = meetings[meetingIndex];
                  final updatedItems = List<ActionItem>.from(
                    meeting.actionItems,
                  );
                  updatedItems[int.parse(todo.actionItem.id)] = updatedItem;
                  final updatedMeeting = meeting.copyWith(
                    actionItems: updatedItems,
                  );
                  await ref
                      .read(meetingsProvider.notifier)
                      .updateMeeting(updatedMeeting);
                }
              },
            ),
            title: Text(
              todo.actionItem.text,
              style: TextStyle(
                decoration: todo.actionItem.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
                color: todo.actionItem.isCompleted ? Colors.grey : null,
              ),
            ),
            subtitle: Text(
              todo.meetingTitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MeetingDetailScreen(meetingId: todo.meetingId),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openMeeting(BuildContext context, Meeting meeting) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeetingDetailScreen(meetingId: meeting.id),
      ),
    );
  }
}

class _MeetingListItem extends StatelessWidget {
  final Meeting meeting;
  final DateFormat dateFormat;
  final DateFormat timeFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MeetingListItem({
    required this.meeting,
    required this.dateFormat,
    required this.timeFormat,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(meeting.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Meeting'),
            content: const Text(
              'Are you sure you want to delete this meeting?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return result ?? false;
      },
      onDismissed: (direction) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.mic,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meeting.title ?? 'Untitled Meeting',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dateFormat.format(meeting.createdAt)} at ${timeFormat.format(meeting.createdAt)}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (meeting.isAnalyzed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Analyzed',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (meeting.summary != null && meeting.summary!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    meeting.summary!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.text_snippet, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${meeting.transcription.split(' ').length} words',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    if (meeting.durationSeconds != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.timer, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        meeting.formattedDuration,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MeetingDetailScreen extends ConsumerStatefulWidget {
  final String meetingId;

  const MeetingDetailScreen({super.key, required this.meetingId});

  @override
  ConsumerState<MeetingDetailScreen> createState() =>
      _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(meetingsProvider.notifier).loadMeetings();
      ref.read(meetingAnalysisProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final meetings = ref.watch(meetingsProvider);
    final meeting = meetings.where((m) => m.id == widget.meetingId).firstOrNull;

    if (meeting == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meeting')),
        body: const Center(child: Text('Meeting not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(meeting.title ?? 'Meeting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Meeting'),
                  content: const Text(
                    'Are you sure you want to delete this meeting?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                ref
                    .read(meetingsProvider.notifier)
                    .deleteMeeting(widget.meetingId);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: TranscriptionView(
        transcription: meeting.transcription,
        isAnalyzed: meeting.isAnalyzed,
        meetingId: meeting.id,
        title: meeting.title,
        tagline: meeting.tagline,
        summary: meeting.summary,
        actionItems: meeting.actionItems.isEmpty
            ? '[]'
            : '["${meeting.actionItems.map((e) => '${e.isCompleted ? '[x] ' : '[ ] '}${e.text.replaceAll('"', '\\"')}').join('", "')}"]',
        decisions: meeting.decisions,
        suggestions: meeting.suggestions,
        dates: meeting.dates
            .map(
              (d) =>
                  'date:${d.dateTime.toIso8601String().split('T')[0]}|time:${d.dateTime.toIso8601String().split('T')[1].split(':')[0]}:${d.dateTime.toIso8601String().split('T')[1].split(':')[1]}|title:${d.title}|desc:${d.description ?? ''}',
            )
            .join('\n'),
        keyTakeaways: meeting.keyTakeaways,
        topic: meeting.topic,
        tags: meeting.tags,
        participants: meeting.participants,
        graphData: meeting.graphData,
        emailDraft: meeting.emailDraft,
        questions: meeting.questions,
        discussionPoints: meeting.discussionPoints,
      ),
    );
  }
}

class SettingsScreenContent extends ConsumerWidget {
  const SettingsScreenContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (config) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Settings',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'AI Analysis (Gemini)'),
          const SizedBox(height: 12),
          _buildApiKeyField(context, ref, config.apiKey),
          const SizedBox(height: 12),
          _buildModelField(context, ref, config.llmModel),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Speech Recognition'),
          const SizedBox(height: 12),
          _buildLanguageSelector(context, ref, config.speechLanguage),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  Widget _buildApiKeyField(BuildContext context, WidgetRef ref, String value) {
    return TextFormField(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'API Key',
        hintText: 'Enter your Gemini API key',
        prefixIcon: Icon(Icons.key),
      ),
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (val) {
        final current = ref.read(settingsProvider).value!;
        ref
            .read(settingsProvider.notifier)
            .updateConfig(current.copyWith(apiKey: val));
      },
    );
  }

  static const List<Map<String, String>> _geminiModels = [
    {'id': 'gemini-2.5-flash', 'name': 'Gemini 2.5 Flash (Recommended)'},
    {'id': 'gemini-2.5-flash-lite', 'name': 'Gemini 2.5 Flash-Lite'},
    {'id': 'gemini-flash-latest', 'name': 'Gemini Flash Latest'},
    {'id': 'gemini-flash-lite-latest', 'name': 'Gemini Flash-Lite Latest'},
    {'id': 'gemini-2.0-flash', 'name': 'Gemini 2.0 Flash'},
    {'id': 'gemini-2.0-flash-lite', 'name': 'Gemini 2.0 Flash-Lite'},
  ];

  Widget _buildModelField(BuildContext context, WidgetRef ref, String value) {
    final selectedModel = _geminiModels.firstWhere(
      (m) => m['id'] == value,
      orElse: () => _geminiModels.first,
    );
    return DropdownButtonFormField<String>(
      value: selectedModel['id'],
      decoration: const InputDecoration(
        labelText: 'Model',
        prefixIcon: Icon(Icons.model_training),
      ),
      items: _geminiModels
          .map((m) => DropdownMenuItem(value: m['id'], child: Text(m['name']!)))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          final current = ref.read(settingsProvider).value!;
          ref
              .read(settingsProvider.notifier)
              .updateConfig(current.copyWith(llmModel: val));
        }
      },
    );
  }

  static const Map<String, String> _languages = {
    'en_US': 'English (US)',
    'en_GB': 'English (UK)',
    'de_DE': 'German',
    'fr_FR': 'French',
    'es_ES': 'Spanish',
    'it_IT': 'Italian',
    'pt_BR': 'Portuguese',
    'nl_NL': 'Dutch',
    'ru_RU': 'Russian',
    'zh_CN': 'Chinese',
    'ja_JP': 'Japanese',
    'ko_KR': 'Korean',
  };

  Widget _buildLanguageSelector(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) {
    return DropdownButtonFormField<String>(
      value: _languages.containsKey(value) ? value : 'en_US',
      decoration: const InputDecoration(
        labelText: 'Language',
        prefixIcon: Icon(Icons.language),
      ),
      items: _languages.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          final current = ref.read(settingsProvider).value!;
          ref
              .read(settingsProvider.notifier)
              .updateConfig(current.copyWith(speechLanguage: val));
        }
      },
    );
  }
}

class _CombinedTodo {
  final String meetingTitle;
  final String meetingId;
  final ActionItem actionItem;
  _CombinedTodo({
    required this.meetingTitle,
    required this.meetingId,
    required this.actionItem,
  });
}
