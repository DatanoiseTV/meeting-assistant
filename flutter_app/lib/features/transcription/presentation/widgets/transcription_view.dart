import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:graphview/GraphView.dart';
import '../../../llm/presentation/providers/llm_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/meeting.dart';
import '../providers/meetings_provider.dart';

class TranscriptionView extends ConsumerStatefulWidget {
  final String transcription;
  final bool isAnalyzed;
  final String? meetingId;
  final String? title;
  final String? tagline;
  final String? summary;
  final String? actionItems;
  final String? decisions;
  final String? suggestions;
  final String? dates;
  final String? keyTakeaways;
  final String? topic;
  final String? tags;
  final String? participants;
  final String? graphData;
  final String? emailDraft;
  final String? questions;
  final String? discussionPoints;
  final String? researchResults;
  final String? researchRecommendations;
  final String? researchComments;
  final VoidCallback? onSwitchToSummaryTab;

  const TranscriptionView({
    super.key,
    required this.transcription,
    this.isAnalyzed = false,
    this.meetingId,
    this.title,
    this.tagline,
    this.summary,
    this.actionItems,
    this.decisions,
    this.suggestions,
    this.dates,
    this.keyTakeaways,
    this.topic,
    this.tags,
    this.participants,
    this.graphData,
    this.emailDraft,
    this.questions,
    this.discussionPoints,
    this.researchResults,
    this.researchRecommendations,
    this.researchComments,
    this.onSwitchToSummaryTab,
  });

  @override
  ConsumerState<TranscriptionView> createState() => _TranscriptionViewState();
}

class _TranscriptionViewState extends ConsumerState<TranscriptionView> {
  int _selectedTab = 0;
  final Map<String, bool> _actionItemStates = {};
  final Map<String, bool?> _decisionApprovals = {};
  bool _loadedStoredAnalysis = false;
  bool _performResearch = false;
  final ScrollController _tabScrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    _tabScrollController.addListener(_updateScrollArrows);
  }

  @override
  void dispose() {
    _tabScrollController.removeListener(_updateScrollArrows);
    _tabScrollController.dispose();
    super.dispose();
  }

  void _updateScrollArrows() {
    if (!_tabScrollController.hasClients) return;
    final position = _tabScrollController.position;
    final showLeft = position.pixels > 0;
    final showRight = position.pixels < position.maxScrollExtent;
    if (showLeft != _showLeftArrow || showRight != _showRightArrow) {
      setState(() {
        _showLeftArrow = showLeft;
        _showRightArrow = showRight;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedStoredAnalysis && widget.isAnalyzed) {
      _loadedStoredAnalysis = true;
      Future.microtask(() {
        final analysisState = ref.read(meetingAnalysisProvider);
        if (analysisState.status != AnalysisStatus.completed) {
          ref
              .read(meetingAnalysisProvider.notifier)
              .loadStoredAnalysis(
                title: widget.title ?? '',
                tagline: widget.tagline ?? '',
                summary: widget.summary ?? '',
                actionItems: widget.actionItems ?? '',
                decisions: widget.decisions ?? '',
                keyTakeaways: widget.keyTakeaways ?? '',
                topic: widget.topic ?? '',
                tags: widget.tags ?? '',
                participants: widget.participants ?? '',
                suggestions: widget.suggestions ?? '',
                dates: widget.dates ?? '',
                graphData: widget.graphData ?? '',
                emailDraft: widget.emailDraft ?? '',
                questions: widget.questions ?? '',
                discussionPoints: widget.discussionPoints ?? '',
                researchResults: widget.researchResults ?? '',
                researchRecommendations: widget.researchRecommendations ?? '',
                researchComments: widget.researchComments ?? '',
              );
        }
      });
    }
  }

  MeetingReport? _getStoredReport() {
    if (!widget.isAnalyzed) return null;
    return MeetingReport(
      title: widget.title ?? '',
      tagline: widget.tagline ?? '',
      overview: widget.summary ?? '',
      participants: widget.participants ?? '',
      tags: widget.tags ?? '',
      topic: widget.topic ?? '',
      summary: widget.summary ?? '',
      keyTakeaways: widget.keyTakeaways ?? '',
      agendaItems: '',
      discussionPoints: widget.discussionPoints ?? '',
      questions: widget.questions ?? '',
      decisions: widget.decisions ?? '',
      suggestions: widget.suggestions ?? '',
      actionItems: widget.actionItems ?? '',
      dates: widget.dates ?? '',
      graphData: widget.graphData ?? '',
      emailDraft: widget.emailDraft ?? '',
      researchResults: widget.researchResults ?? '',
      researchRecommendations: widget.researchRecommendations ?? '',
      researchComments: widget.researchComments ?? '',
    );
  }

  Future<void> _saveMeetingWithAnalysis(MeetingReport report) async {
    if (widget.meetingId == null) return;
    final meetings = ref.read(meetingsProvider);
    final meeting = meetings.where((m) => m.id == widget.meetingId).firstOrNull;
    if (meeting == null) return;

    final actionItems = ActionItemsHelper.parseFromJsonString(
      report.actionItems,
    );

    final dates = report.parsedDates
        .map(
          (e) => MeetingDate(
            id: e.id,
            title: e.title,
            dateTime: e.dateTime,
            description: e.description,
          ),
        )
        .toList();

    final updatedMeeting = meeting.copyWith(
      title: report.title.isNotEmpty ? report.title : null,
      summary: report.summary.isNotEmpty ? report.summary : null,
      participants: report.participants.isNotEmpty ? report.participants : null,
      tags: report.tags.isNotEmpty ? report.tags : null,
      topic: report.topic.isNotEmpty ? report.topic : null,
      keyTakeaways: report.keyTakeaways.isNotEmpty ? report.keyTakeaways : null,
      discussionPoints: report.discussionPoints.isNotEmpty
          ? report.discussionPoints
          : null,
      questions: report.questions.isNotEmpty ? report.questions : null,
      decisions: report.decisions.isNotEmpty ? report.decisions : null,
      suggestions: report.suggestions.isNotEmpty ? report.suggestions : null,
      actionItems: actionItems,
      dates: dates,
      graphData: report.graphData.isNotEmpty ? report.graphData : null,
      emailDraft: report.emailDraft.isNotEmpty ? report.emailDraft : null,
      isAnalyzed: true,
      researchResults: report.researchResults.isNotEmpty
          ? report.researchResults
          : null,
      researchRecommendations: report.researchRecommendations.isNotEmpty
          ? report.researchRecommendations
          : null,
      researchComments: report.researchComments.isNotEmpty
          ? report.researchComments
          : null,
    );

    await ref.read(meetingsProvider.notifier).updateMeeting(updatedMeeting);
  }

  @override
  Widget build(BuildContext context) {
    final analysisState = ref.watch(meetingAnalysisProvider);
    final providerReport = analysisState.report;

    ref.listen(meetingAnalysisProvider, (previous, next) {
      if (previous?.status == AnalysisStatus.analyzing &&
          next.status == AnalysisStatus.completed &&
          next.report != null &&
          widget.meetingId != null) {
        _saveMeetingWithAnalysis(next.report!);
      }
    });

    final isAnalyzing = analysisState.status == AnalysisStatus.analyzing;

    final hasAnalysisInState =
        providerReport != null &&
        analysisState.status == AnalysisStatus.completed;
    final storedReport = _getStoredReport();
    final report = providerReport ?? storedReport;
    final showAsAnalyzed = hasAnalysisInState || storedReport != null;

    final hasActionItems =
        showAsAnalyzed && report != null && _hasContent(report.actionItems);
    final hasDecisions =
        showAsAnalyzed && report != null && _hasContent(report.decisions);
    final hasSuggestions =
        showAsAnalyzed && report != null && _hasContent(report.suggestions);
    final hasDates =
        showAsAnalyzed && report != null && report.parsedDates.isNotEmpty;
    final hasKeyTakeaways =
        showAsAnalyzed && report != null && _hasContent(report.keyTakeaways);
    final hasMermaid =
        showAsAnalyzed && report != null && _hasContent(report.graphData);
    final hasEmail =
        showAsAnalyzed && report != null && _hasContent(report.emailDraft);
    final hasQuestions =
        showAsAnalyzed && report != null && _hasContent(report.questions);
    final hasDiscussion =
        showAsAnalyzed &&
        report != null &&
        _hasContent(report.discussionPoints);
    final hasTopic =
        showAsAnalyzed && report != null && _hasContent(report.topic);
    final hasTags =
        showAsAnalyzed && report != null && _hasContent(report.tags);
    final hasParticipants =
        showAsAnalyzed && report != null && _hasContent(report.participants);
    final hasResearch =
        showAsAnalyzed &&
        report != null &&
        (_hasContent(report.researchResults) ||
            _hasContent(report.researchRecommendations));

    final tabs = <_TabItem>[_TabItem(title: 'Transcript', icon: Icons.article)];
    if (showAsAnalyzed) {
      if (hasActionItems)
        tabs.add(_TabItem(title: 'Tasks', icon: Icons.checklist));
      if (hasDecisions)
        tabs.add(_TabItem(title: 'Decisions', icon: Icons.gavel));
      if (hasSuggestions)
        tabs.add(_TabItem(title: 'Suggestions', icon: Icons.lightbulb_outline));
      if (hasDates) tabs.add(_TabItem(title: 'Dates', icon: Icons.event));
      if (hasResearch)
        tabs.add(_TabItem(title: 'Research', icon: Icons.search));
      if (hasKeyTakeaways ||
          hasTopic ||
          hasTags ||
          hasParticipants ||
          (report != null && _hasContent(report.summary))) {
        tabs.add(_TabItem(title: 'Summary', icon: Icons.summarize));
      }
      if (hasMermaid || hasEmail || hasQuestions || hasDiscussion) {
        tabs.add(_TabItem(title: 'Details', icon: Icons.more_horiz));
      }
    }

    if (_selectedTab >= tabs.length) _selectedTab = 0;

    return Column(
      children: [
        // Horizontal scrollable tabs at top
        if (tabs.length > 1)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 48,
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _tabScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: tabs.length,
                      itemBuilder: (context, index) {
                        final tab = tabs[index];
                        final isSelected = index == _selectedTab;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTab = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  tab.icon,
                                  size: 18,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tab.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Left fade indicator
                    if (_showLeftArrow)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.surface,
                                Theme.of(
                                  context,
                                ).colorScheme.surface.withOpacity(0),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    // Right fade indicator
                    if (_showRightArrow)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(
                                  context,
                                ).colorScheme.surface.withOpacity(0),
                                Theme.of(context).colorScheme.surface,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

        // Main content
        Expanded(
          child: isAnalyzing
              ? _buildAnalyzingState(context)
              : _buildCurrentTabContent(report, tabs),
        ),

        // Error banner
        if (analysisState.status == AnalysisStatus.error)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    analysisState.errorMessage ?? 'Error',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // Fixed bottom action bar
        if (_selectedTab == 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactPersonaDropdown(context, ref),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: isAnalyzing
                            ? null
                            : () => _handleAnalyze(ref),
                        icon: Icon(
                          isAnalyzing
                              ? Icons.hourglass_empty
                              : Icons.psychology,
                          size: 20,
                        ),
                        label: Text(
                          isAnalyzing
                              ? 'Analyzing...'
                              : (showAsAnalyzed ? 'Re-analyze' : 'Analyze'),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _performResearch,
                        onChanged: (value) {
                          setState(() => _performResearch = value ?? false);
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _performResearch = !_performResearch);
                        },
                        child: Text(
                          'Perform research (web search)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactPersonaDropdown(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return settings.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (config) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: config.persona.isEmpty ? 'general' : config.persona,
            hint: const Text('Focus'),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'general', child: Text('General')),
              DropdownMenuItem(value: 'dev', child: Text('Developer')),
              DropdownMenuItem(value: 'pm', child: Text('PM')),
              DropdownMenuItem(value: 'exec', child: Text('Exec')),
            ],
            onChanged: (val) {
              if (val != null) {
                final current = ref.read(settingsProvider).value!;
                ref
                    .read(settingsProvider.notifier)
                    .updateConfig(current.copyWith(persona: val));
              }
            },
          ),
        ),
      ),
    );
  }

  void _handleAnalyze(WidgetRef ref) {
    final currentReport = ref.read(meetingAnalysisProvider).report;

    ref.read(meetingAnalysisProvider.notifier).reset();

    if (_performResearch) {
      ref
          .read(meetingAnalysisProvider.notifier)
          .researchTopics(widget.transcription, existingReport: currentReport);
    } else {
      ref
          .read(meetingAnalysisProvider.notifier)
          .analyzeMeeting(widget.transcription);
    }
  }

  bool _hasContent(String? content) {
    if (content == null || content.isEmpty) return false;
    final lower = content.toLowerCase();
    return ![
      'n/a',
      'none',
      'not specified',
      'not explicitly stated',
      'none recorded',
    ].contains(lower);
  }

  Widget _buildAnalyzingState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Analyzing meeting...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'AI is extracting insights',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptTab(
    BuildContext context,
    WidgetRef ref,
    bool showAsAnalyzed,
    int tabCount,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Transcript',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${widget.transcription.split(' ').length} words',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.transcription));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                widget.transcription,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
            ),
          ),
          if (showAsAnalyzed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (tabCount > 1) {
                    setState(() => _selectedTab = 1);
                  }
                },
                icon: const Icon(Icons.visibility),
                label: const Text('View Analysis'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentTabContent(MeetingReport? report, List<_TabItem> tabs) {
    if (_selectedTab == 0) {
      return _buildTranscriptTab(
        context,
        ref,
        report != null && report.summary.isNotEmpty,
        tabs.length,
      );
    }
    return _buildAnalysisTab(context, report, tabs[_selectedTab].title);
  }

  Widget _buildAnalysisTab(
    BuildContext context,
    MeetingReport? report,
    String tabTitle,
  ) {
    if (report == null) return const SizedBox();

    final content = _buildTabContent(report, tabTitle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            tabTitle,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildTabContent(MeetingReport report, String tabTitle) {
    if (tabTitle == 'Tasks') return _buildTasksTab(context, report);
    if (tabTitle == 'Decisions') return _buildDecisionsTab(context, report);
    if (tabTitle == 'Suggestions') return _buildSuggestionsTab(context, report);
    if (tabTitle == 'Dates') return _buildDatesTab(context, report);
    if (tabTitle == 'Research') return _buildResearchTab(context, report);
    if (tabTitle == 'Summary') return _buildSummaryTab(context, report);
    return _buildDetailsTab(context, report);
  }

  Widget _buildResearchTab(BuildContext context, MeetingReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasContent(report.researchResults))
            _buildContentCard(
              context,
              'Research Findings',
              report.researchResults,
            ),
          if (_hasContent(report.researchRecommendations))
            _buildContentCard(
              context,
              'Recommendations',
              report.researchRecommendations,
            ),
          if (_hasContent(report.researchComments))
            _buildContentCard(context, 'Comments', report.researchComments),
        ],
      ),
    );
  }

  Widget _buildTasksTab(BuildContext context, MeetingReport report) {
    final items = _parseActionItems(report);
    if (items.isEmpty)
      return Center(
        child: Text('No tasks', style: TextStyle(color: Colors.grey.shade600)),
      );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: items.map((item) {
          final isCompleted = _actionItemStates[item.id] ?? item.isCompleted;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Checkbox(
                value: isCompleted,
                onChanged: (v) =>
                    setState(() => _actionItemStates[item.id] = v ?? false),
              ),
              title: Text(
                item.text,
                style: TextStyle(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted ? Colors.grey : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDecisionsTab(BuildContext context, MeetingReport report) {
    final decisions = _parseList(report.decisions);
    if (decisions.isEmpty)
      return Center(
        child: Text(
          'No decisions',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: decisions.asMap().entries.map((entry) {
          final decision = entry.value;
          final decisionId = 'd_${entry.key}';
          final approval = _decisionApprovals[decisionId];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(decision, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(
                            () => _decisionApprovals[decisionId] = true,
                          ),
                          icon: const Icon(Icons.thumb_up, size: 18),
                          label: const Text('Approve'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: approval == true
                                ? Colors.white
                                : Colors.green,
                            backgroundColor: approval == true
                                ? Colors.green
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(
                            () => _decisionApprovals[decisionId] = false,
                          ),
                          icon: const Icon(Icons.thumb_down, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: approval == false
                                ? Colors.white
                                : Colors.red,
                            backgroundColor: approval == false
                                ? Colors.red
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  final Map<String, bool?> _suggestionApprovals = {};

  Widget _buildSuggestionsTab(BuildContext context, MeetingReport report) {
    final suggestions = report.suggestionList;
    if (suggestions.isEmpty) {
      return Center(
        child: Text(
          'No suggestions',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        final approval = _suggestionApprovals[suggestion.id];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion.text,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _suggestionApprovals[suggestion.id] = true,
                        ),
                        icon: const Icon(Icons.thumb_up, size: 18),
                        label: const Text('Accept'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: approval == true
                              ? Colors.white
                              : Colors.green,
                          backgroundColor: approval == true
                              ? Colors.green
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _suggestionApprovals[suggestion.id] = false,
                        ),
                        icon: const Icon(Icons.thumb_down, size: 18),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: approval == false
                              ? Colors.white
                              : Colors.red,
                          backgroundColor: approval == false
                              ? Colors.red
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDatesTab(BuildContext context, MeetingReport report) {
    final dates = report.parsedDates;
    if (dates.isEmpty) {
      return Center(
        child: Text(
          'No dates found',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.event, color: Colors.orange.shade700),
            ),
            title: Text(date.title),
            subtitle: Text(
              '${date.dateTime.day}/${date.dateTime.month}/${date.dateTime.year} at ${date.dateTime.hour.toString().padLeft(2, '0')}:${date.dateTime.minute.toString().padLeft(2, '0')}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _exportToCalendar(date),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportToCalendar(ParsedDate date) async {
    final uri = Uri(
      scheme: 'mailto',
      query:
          'subject=${Uri.encodeComponent(date.title)}&body=${Uri.encodeComponent('Date: ${date.dateTime}\n\n${date.description ?? ''}')}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Widget _buildSummaryTab(BuildContext context, MeetingReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasContent(report.title)) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_hasContent(report.topic)) ...[
                      const SizedBox(height: 8),
                      Text(
                        report.topic,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_hasContent(report.summary))
            _buildContentCard(context, 'Summary', report.summary),
          if (_hasContent(report.keyTakeaways))
            _buildContentCard(context, 'Key Takeaways', report.keyTakeaways),
          if (_hasContent(report.participants))
            _buildContentCard(context, 'Participants', report.participants),
          if (_hasContent(report.tags))
            _buildContentCard(context, 'Tags', report.tags),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(BuildContext context, MeetingReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasContent(report.questions))
            _buildContentCard(context, 'Questions', report.questions),
          if (_hasContent(report.discussionPoints))
            _buildContentCard(context, 'Discussion', report.discussionPoints),
          if (_hasContent(report.graphData)) _buildGraphCard(context, report),
          if (_hasContent(report.emailDraft))
            _buildEmailCard(context, report.emailDraft),
        ],
      ),
    );
  }

  Widget _buildContentCard(BuildContext context, String title, String content) {
    final items = _parseList(content);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphCard(BuildContext context, MeetingReport report) {
    final edges = report.graphEdges;
    final nodes = report.graphNodes;

    if (edges.isEmpty) return const SizedBox();

    final graph = Graph();
    final nodeMap = <String, Node>{};

    for (final nodeId in nodes) {
      final node = Node.Id(nodeId);
      nodeMap[nodeId] = node;
      graph.addNode(node);
    }

    for (final edge in edges) {
      if (nodeMap.containsKey(edge.from) && nodeMap.containsKey(edge.to)) {
        graph.addEdge(nodeMap[edge.from]!, nodeMap[edge.to]!);
      }
    }

    final builder = SugiyamaConfiguration()
      ..bendPointShape = CurvedBendPointShape(curveLength: 15)
      ..levelSeparation = 50
      ..nodeSeparation = 20;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Meeting Flow',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: report.graphData)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: nodes.length > 5 ? 350 : 200,
              child: InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(50),
                minScale: 0.3,
                maxScale: 2.0,
                child: GraphView(
                  graph: graph,
                  algorithm: SugiyamaAlgorithm(builder),
                  paint: Paint()
                    ..color = Colors.orange.shade700
                    ..strokeWidth = 2
                    ..style = PaintingStyle.stroke,
                  builder: (Node node) {
                    final nodeId = node.key!.value as String;
                    return _buildGraphNode(context, nodeId);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphNode(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.shade700, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.orange.shade900,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildEmailCard(BuildContext context, String email) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Email Draft',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.mail, size: 20),
                  onPressed: () => _sendEmail(email),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: email)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              email,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  List<String> _parseList(String text) {
    if (text.isEmpty) return [];

    // If it looks like a JSON array, try to parse it
    if (text.trim().startsWith('[')) {
      try {
        final cleaned = text.trim();
        if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
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
          if (result.isNotEmpty) return result;
        }
      } catch (_) {}
    }

    // Fallback: split by newlines and remove dashes/bullets
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => l.replaceFirst(RegExp(r'^[-*•] ?'), ''))
        .toList();
  }

  List<_ActionItemData> _parseActionItems(MeetingReport report) {
    final items = <_ActionItemData>[];
    final actionItems = report.actionItemsList;

    for (var i = 0; i < actionItems.length; i++) {
      final task = actionItems[i];
      if (task.isEmpty) continue;
      items.add(
        _ActionItemData(
          id: i.toString(),
          text: task,
          isCompleted: task.contains('[x]'),
        ),
      );
    }
    return items;
  }

  Future<void> _sendEmail(String body) async {
    final uri = Uri(
      scheme: 'mailto',
      query: 'subject=Meeting Summary&body=${Uri.encodeComponent(body)}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _TabItem {
  final String title;
  final IconData icon;
  _TabItem({required this.title, required this.icon});
}

class _ActionItemData {
  final String id;
  final String text;
  final bool isCompleted;
  _ActionItemData({
    required this.id,
    required this.text,
    required this.isCompleted,
  });
}
