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
import '../../data/services/pdf_export_service.dart';
import 'settings_screen.dart';

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
            _buildSearchView(context),
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
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
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
    final meetings = ref.watch(meetingsProvider);
    final isRecording =
        transcriptionState.status == TranscriptionStatus.recording;
    final isCompleted =
        transcriptionState.status == TranscriptionStatus.completed;

    final totalMeetings = meetings.length;
    final analyzedMeetings = meetings.where((m) => m.isAnalyzed).length;
    final totalTasks = meetings.fold<int>(
      0,
      (sum, m) => sum + m.actionItems.length,
    );
    final completedTasks = meetings.fold<int>(
      0,
      (sum, m) => sum + m.actionItems.where((a) => a.isCompleted).length,
    );
    final recentMeetings = meetings.take(3).toList();

    return CustomScrollView(
      slivers: [
        // Hero Section
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [const Color(0xFF1C1C1E), const Color(0xFF2C2C2E)]
                    : [Colors.black, Colors.black.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  'Meeting Assistant',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isRecording
                      ? 'Recording in progress...'
                      : isCompleted
                      ? 'Recording complete!'
                      : 'Record your meetings and get AI-powered insights',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Animated Record Button
                GestureDetector(
                  onTap: () {
                    if (transcriptionState.status == TranscriptionStatus.idle) {
                      ref.read(transcriptionProvider.notifier).startRecording();
                    } else if (isRecording) {
                      ref.read(transcriptionProvider.notifier).stopRecording();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isRecording ? 80 : 100,
                    height: isRecording ? 80 : 100,
                    decoration: BoxDecoration(
                      color: isRecording ? Colors.red : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isRecording ? Colors.red : Colors.white)
                              .withOpacity(0.3),
                          blurRadius: isRecording ? 30 : 20,
                          spreadRadius: isRecording ? 10 : 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      isRecording ? Icons.stop : Icons.mic,
                      size: isRecording ? 40 : 48,
                      color: isRecording
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Status Text
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(transcriptionState.status),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isCompleted) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(transcriptionProvider.notifier).reset();
                      setState(() => _selectedIndex = 1);
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Meeting'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    ref
                        .read(transcriptionProvider.notifier)
                        .importTranscriptFromFile();
                  },
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: const Text(
                    'Import from file',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // Quick Stats
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    Icons.article,
                    '$totalMeetings',
                    'Meetings',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    Icons.psychology,
                    '$analyzedMeetings',
                    'Analyzed',
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    Icons.check_circle,
                    '$completedTasks/$totalTasks',
                    'Tasks',
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Recent Meetings Section
        if (recentMeetings.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Meetings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedIndex = 1),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: recentMeetings.length,
                itemBuilder: (context, index) {
                  final meeting = recentMeetings[index];
                  return _buildRecentMeetingCard(context, meeting);
                },
              ),
            ),
          ),
        ],

        // Empty state for new users
        if (totalMeetings == 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.record_voice_over,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No meetings yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the record button to start your first meeting',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  String _getStatusText(TranscriptionStatus status) {
    switch (status) {
      case TranscriptionStatus.idle:
        return 'Tap to start recording';
      case TranscriptionStatus.recording:
        return 'Listening...';
      case TranscriptionStatus.processing:
        return 'Initializing...';
      case TranscriptionStatus.transcribing:
        return 'Processing...';
      case TranscriptionStatus.completed:
        return 'Recording complete!';
      case TranscriptionStatus.error:
        return 'Error occurred';
    }
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentMeetingCard(BuildContext context, Meeting meeting) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingDetailScreen(meetingId: meeting.id),
          ),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.article,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                if (meeting.isAnalyzed)
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
              ],
            ),
            const Spacer(),
            Text(
              meeting.title ?? 'Untitled',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(meeting.createdAt),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
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
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.folder_open,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No meetings yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Record your first meeting to get started',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => setState(() => _selectedIndex = 0),
                icon: const Icon(Icons.mic),
                label: const Text('Start Recording'),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Text(
                  'All Meetings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${meetings.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Meetings List
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final meeting = meetings[index];
              return _buildMeetingCard(context, meeting);
            }, childCount: meetings.length),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildMeetingCard(BuildContext context, Meeting meeting) {
    return Dismissible(
      key: Key(meeting.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
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
            ) ??
            false;
      },
      onDismissed: (direction) {
        ref.read(meetingsProvider.notifier).deleteMeeting(meeting.id);
      },
      child: GestureDetector(
        onTap: () => _openMeeting(context, meeting),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: meeting.isAnalyzed
                      ? Colors.green.withOpacity(0.1)
                      : Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: meeting.isAnalyzed
                            ? Colors.green.withOpacity(0.2)
                            : Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        meeting.isAnalyzed ? Icons.psychology : Icons.mic,
                        color: meeting.isAnalyzed
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
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
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(meeting.createdAt),
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
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Analyzed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (meeting.summary != null &&
                        meeting.summary!.isNotEmpty) ...[
                      Text(
                        meeting.summary!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Tags and stats row
                    Row(
                      children: [
                        // Tags
                        if (meeting.tags != null && meeting.tags!.isNotEmpty)
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _parseTags(meeting.tags!)
                                  .take(3)
                                  .map(
                                    (tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        tag.replaceAll('_', ' '),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),

                        // Stats
                        if (meeting.actionItems.isNotEmpty) ...[
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${meeting.actionItems.where((a) => a.isCompleted).length}/${meeting.actionItems.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _parseTags(String tags) {
    try {
      if (tags.startsWith('[')) {
        return tags
            .replaceAll('[', '')
            .replaceAll(']', '')
            .split(',')
            .map((e) => e.trim().replaceAll('"', ''))
            .toList();
      }
    } catch (_) {}
    return [tags];
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String selected,
    Function(String) onSelected,
  ) {
    final isSelected = value == selected;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildSearchView(BuildContext context) {
    final meetings = ref.watch(meetingsProvider);
    final searchController = TextEditingController();
    String _selectedFilter = 'all';

    return StatefulBuilder(
      builder: (context, setSearchState) {
        final query = searchController.text.toLowerCase();

        var filteredMeetings = query.isEmpty
            ? List<Meeting>.from(meetings)
            : meetings.where((m) {
                final title = m.title?.toLowerCase() ?? '';
                final summary = m.summary?.toLowerCase() ?? '';
                final transcription = m.transcription.toLowerCase();
                final tags = m.tags?.toLowerCase() ?? '';
                return title.contains(query) ||
                    summary.contains(query) ||
                    transcription.contains(query) ||
                    tags.contains(query);
              }).toList();

        if (_selectedFilter == 'analyzed') {
          filteredMeetings = filteredMeetings
              .where((m) => m.isAnalyzed)
              .toList();
        } else if (_selectedFilter == 'hasTasks') {
          filteredMeetings = filteredMeetings
              .where((m) => m.actionItems.isNotEmpty)
              .toList();
        } else if (_selectedFilter == 'thisWeek') {
          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
          filteredMeetings = filteredMeetings
              .where((m) => m.createdAt.isAfter(weekAgo))
              .toList();
        } else if (_selectedFilter == 'thisMonth') {
          final monthAgo = DateTime.now().subtract(const Duration(days: 30));
          filteredMeetings = filteredMeetings
              .where((m) => m.createdAt.isAfter(monthAgo))
              .toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search meetings...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            setSearchState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setSearchState(() {}),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', _selectedFilter, (val) {
                    setSearchState(() => _selectedFilter = val);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Analyzed', 'analyzed', _selectedFilter, (
                    val,
                  ) {
                    setSearchState(() => _selectedFilter = val);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Has Tasks', 'hasTasks', _selectedFilter, (
                    val,
                  ) {
                    setSearchState(() => _selectedFilter = val);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('This Week', 'thisWeek', _selectedFilter, (
                    val,
                  ) {
                    setSearchState(() => _selectedFilter = val);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('This Month', 'thisMonth', _selectedFilter, (
                    val,
                  ) {
                    setSearchState(() => _selectedFilter = val);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredMeetings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            query.isEmpty && _selectedFilter == 'all'
                                ? Icons.search
                                : Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            query.isEmpty && _selectedFilter == 'all'
                                ? 'Search your meetings'
                                : 'No results found',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            query.isEmpty && _selectedFilter == 'all'
                                ? 'Find by title, content, or tags'
                                : 'Try adjusting your filters',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredMeetings.length,
                      itemBuilder: (context, index) {
                        final meeting = filteredMeetings[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.article,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              meeting.title ?? 'Untitled Meeting',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              meeting.summary ?? meeting.transcription,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MeetingDetailScreen(
                                    meetingId: meeting.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
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

    final completedCount = allTodos
        .where((t) => t.actionItem.isCompleted)
        .length;
    final totalCount = allTodos.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'All Todos',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$completedCount/$totalCount done',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    progress == 1.0
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              todo.meetingTitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        title: Text(
          meeting.title ?? 'Meeting',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final pdfService = PdfExportService();
              await pdfService.sharePdf(meeting);
            },
          ),
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
        researchResults: meeting.researchResults,
        researchRecommendations: meeting.researchRecommendations,
        researchComments: meeting.researchComments,
      ),
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
