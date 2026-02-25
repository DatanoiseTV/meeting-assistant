class AppConfig {
  final String modelPath;
  final String modelDownloadHost;
  final String provider;
  final String apiKey;
  final String llmModel;
  final String? customApiUrl;
  final String outputDir;
  final String obsidianVaultPath;
  final String persona;
  final String speechLanguage;
  final bool enableResearch;
  final bool useWhisper;
  final String whisperModel;
  final String? githubToken;
  final String? githubRepo;
  final String? gitlabToken;
  final String? gitlabRepo;
  final double vadThreshold;
  final int vadSilenceMs;

  const AppConfig({
    this.modelPath = '',
    this.modelDownloadHost =
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main',
    this.provider = 'gemini',
    this.apiKey = '',
    this.llmModel = 'gemini-2.5-flash-lite',
    this.customApiUrl,
    this.outputDir = '',
    this.obsidianVaultPath = '',
    this.persona = 'general',
    this.speechLanguage = 'en_US',
    this.enableResearch = false,
    this.useWhisper = false,
    this.whisperModel = 'tiny',
    this.githubToken,
    this.githubRepo,
    this.gitlabToken,
    this.gitlabRepo,
    this.vadThreshold = 0.01,
    this.vadSilenceMs = 1500,
  });

  AppConfig copyWith({
    String? modelPath,
    String? modelDownloadHost,
    String? provider,
    String? apiKey,
    String? llmModel,
    String? customApiUrl,
    String? outputDir,
    String? obsidianVaultPath,
    String? persona,
    String? speechLanguage,
    bool? enableResearch,
    bool? useWhisper,
    String? whisperModel,
    String? githubToken,
    String? githubRepo,
    String? gitlabToken,
    String? gitlabRepo,
    double? vadThreshold,
    int? vadSilenceMs,
  }) {
    return AppConfig(
      modelPath: modelPath ?? this.modelPath,
      modelDownloadHost: modelDownloadHost ?? this.modelDownloadHost,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      llmModel: llmModel ?? this.llmModel,
      customApiUrl: customApiUrl ?? this.customApiUrl,
      outputDir: outputDir ?? this.outputDir,
      obsidianVaultPath: obsidianVaultPath ?? this.obsidianVaultPath,
      persona: persona ?? this.persona,
      speechLanguage: speechLanguage ?? this.speechLanguage,
      enableResearch: enableResearch ?? this.enableResearch,
      useWhisper: useWhisper ?? this.useWhisper,
      whisperModel: whisperModel ?? this.whisperModel,
      githubToken: githubToken ?? this.githubToken,
      githubRepo: githubRepo ?? this.githubRepo,
      gitlabToken: gitlabToken ?? this.gitlabToken,
      gitlabRepo: gitlabRepo ?? this.gitlabRepo,
      vadThreshold: vadThreshold ?? this.vadThreshold,
      vadSilenceMs: vadSilenceMs ?? this.vadSilenceMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'model_path': modelPath,
    'model_download_host': modelDownloadHost,
    'provider': provider,
    'api_key': apiKey,
    'llm_model': llmModel,
    'custom_api_url': customApiUrl,
    'output_dir': outputDir,
    'obsidian_vault_path': obsidianVaultPath,
    'persona': persona,
    'speech_language': speechLanguage,
    'enable_research': enableResearch,
    'use_whisper': useWhisper,
    'whisper_model': whisperModel,
    'github_token': githubToken,
    'github_repo': githubRepo,
    'gitlab_token': gitlabToken,
    'gitlab_repo': gitlabRepo,
    'vad_threshold': vadThreshold,
    'vad_silence_ms': vadSilenceMs,
  };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    modelPath: json['model_path'] ?? '',
    modelDownloadHost:
        json['model_download_host'] ??
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main',
    provider: json['provider'] ?? 'gemini',
    apiKey: json['api_key'] ?? '',
    llmModel: json['llm_model'] ?? 'gemini-2.5-flash-lite',
    customApiUrl: json['custom_api_url'],
    outputDir: json['output_dir'] ?? '',
    obsidianVaultPath: json['obsidian_vault_path'] ?? '',
    persona: json['persona'] ?? 'general',
    speechLanguage: json['speech_language'] ?? 'en_US',
    enableResearch: json['enable_research'] ?? false,
    useWhisper: json['use_whisper'] ?? false,
    whisperModel: json['whisper_model'] ?? 'tiny',
    githubToken: json['github_token'],
    githubRepo: json['github_repo'],
    gitlabToken: json['gitlab_token'],
    gitlabRepo: json['gitlab_repo'],
    vadThreshold: (json['vad_threshold'] ?? 0.01).toDouble(),
    vadSilenceMs: json['vad_silence_ms'] ?? 1500,
  );
}
