import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

class SettingsScreenContent extends ConsumerStatefulWidget {
  const SettingsScreenContent({super.key});

  @override
  ConsumerState<SettingsScreenContent> createState() =>
      _SettingsScreenContentState();
}

class _SettingsScreenContentState extends ConsumerState<SettingsScreenContent> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (config) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure your meeting assistant',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _buildSectionHeader(
              context,
              'AI Configuration',
              Icons.psychology,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildApiKeyField(context, ref, config.apiKey),
                      const SizedBox(height: 16),
                      _buildModelField(context, ref, config.llmModel),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _buildSectionHeader(
              context,
              'Speech Recognition',
              Icons.mic,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Offline Transcription'),
                        subtitle: const Text(
                          'Use on-device Whisper model instead of live speech recognition. Downloads model on first use.',
                        ),
                        secondary: const Icon(Icons.offline_bolt),
                        value: config.useWhisper,
                        onChanged: (val) {
                          final current = ref.read(settingsProvider).value!;
                          ref
                              .read(settingsProvider.notifier)
                              .updateConfig(current.copyWith(useWhisper: val));
                        },
                      ),
                      if (config.useWhisper) ...[
                        const Divider(height: 24),
                        _buildWhisperModelSelector(
                          context,
                          ref,
                          config.whisperModel,
                        ),
                      ],
                      const Divider(height: 24),
                      _buildLanguageSelector(
                        context,
                        ref,
                        config.speechLanguage,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: InkWell(
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Advanced Settings',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Custom API URL, persona, and more',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _showAdvanced ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_showAdvanced) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, 'Advanced AI', Icons.cloud),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildCustomUrlField(context, ref, config.customApiUrl),
                        const SizedBox(height: 16),
                        _buildPersonaField(context, ref, config.persona),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _buildSectionHeader(context, 'Research', Icons.search),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Research'),
                      subtitle: const Text('Research topics using web search'),
                      value: config.enableResearch,
                      onChanged: (val) {
                        final current = ref.read(settingsProvider).value!;
                        ref
                            .read(settingsProvider.notifier)
                            .updateConfig(
                              current.copyWith(enableResearch: val),
                            );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyField(BuildContext context, WidgetRef ref, String value) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'API Key',
        hintText: 'Enter your Gemini API key',
        prefixIcon: const Icon(Icons.key),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
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
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Model',
        prefixIcon: const Icon(Icons.model_training),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: _geminiModels
          .map(
            (m) => DropdownMenuItem(
              value: m['id'],
              child: Text(m['name']!, overflow: TextOverflow.ellipsis),
            ),
          )
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
      decoration: InputDecoration(
        labelText: 'Language',
        prefixIcon: const Icon(Icons.language),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
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

  static const List<Map<String, String>> _whisperModels = [
    {'id': 'tiny', 'name': 'Tiny (~75 MB, fastest)'},
    {'id': 'base', 'name': 'Base (~142 MB, fast)'},
    {'id': 'small', 'name': 'Small (~466 MB, balanced)'},
    {'id': 'medium', 'name': 'Medium (~1.5 GB, accurate)'},
    {'id': 'large-v1', 'name': 'Large v1 (~2.9 GB, best)'},
    {'id': 'large-v2', 'name': 'Large v2 (~2.9 GB, best)'},
  ];

  Widget _buildWhisperModelSelector(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) {
    final selected = _whisperModels.firstWhere(
      (m) => m['id'] == value,
      orElse: () => _whisperModels.first,
    );
    return DropdownButtonFormField<String>(
      value: selected['id'],
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Whisper Model',
        prefixIcon: const Icon(Icons.memory),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: _whisperModels
          .map(
            (m) => DropdownMenuItem(
              value: m['id'],
              child: Text(m['name']!, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (val) {
        if (val != null) {
          final current = ref.read(settingsProvider).value!;
          ref
              .read(settingsProvider.notifier)
              .updateConfig(current.copyWith(whisperModel: val));
        }
      },
    );
  }

  Widget _buildCustomUrlField(
    BuildContext context,
    WidgetRef ref,
    String? value,
  ) {
    return TextFormField(
      initialValue: value ?? '',
      decoration: InputDecoration(
        labelText: 'Custom API URL (optional)',
        hintText: 'https://api.example.com',
        prefixIcon: const Icon(Icons.link),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      onChanged: (val) {
        final current = ref.read(settingsProvider).value!;
        ref
            .read(settingsProvider.notifier)
            .updateConfig(
              current.copyWith(customApiUrl: val.isEmpty ? null : val),
            );
      },
    );
  }

  Widget _buildPersonaField(BuildContext context, WidgetRef ref, String value) {
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? 'general' : value,
      decoration: InputDecoration(
        labelText: 'Focus / Persona',
        prefixIcon: const Icon(Icons.person),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: const [
        DropdownMenuItem(value: 'general', child: Text('General')),
        DropdownMenuItem(value: 'dev', child: Text('Developer')),
        DropdownMenuItem(value: 'pm', child: Text('Product Manager')),
        DropdownMenuItem(value: 'exec', child: Text('Executive')),
      ],
      onChanged: (val) {
        if (val != null) {
          final current = ref.read(settingsProvider).value!;
          ref
              .read(settingsProvider.notifier)
              .updateConfig(current.copyWith(persona: val));
        }
      },
    );
  }
}
