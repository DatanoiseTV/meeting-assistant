class Config {
  String modelPath;
  String provider;
  String apiKey;
  String llmModel;
  String outputDir;
  String mode;
  String obsidianVaultPath;
  String persona;
  bool research;
  String githubToken;
  String githubRepo;
  String gitlabToken;
  String gitlabRepo;
  double vadThreshold;
  int vadSilenceMs;

  Config({
    this.modelPath = '',
    this.provider = '',
    this.apiKey = '',
    this.llmModel = '',
    this.outputDir = '',
    this.mode = 'standard',
    this.obsidianVaultPath = '',
    this.persona = 'general',
    this.research = false,
    this.githubToken = '',
    this.githubRepo = '',
    this.gitlabToken = '',
    this.gitlabRepo = '',
    this.vadThreshold = 0.01,
    this.vadSilenceMs = 1500,
  });

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      modelPath: json['model_path'] ?? '',
      provider: json['provider'] ?? '',
      apiKey: json['api_key'] ?? '',
      llmModel: json['llm_model'] ?? '',
      outputDir: json['output_dir'] ?? '',
      mode: json['mode'] ?? 'standard',
      obsidianVaultPath: json['obsidian_vault_path'] ?? '',
      persona: json['persona'] ?? 'general',
      research: json['research'] ?? false,
      githubToken: json['github_token'] ?? '',
      githubRepo: json['github_repo'] ?? '',
      gitlabToken: json['gitlab_token'] ?? '',
      gitlabRepo: json['gitlab_repo'] ?? '',
      vadThreshold: (json['vad_threshold'] ?? 0.01).toDouble(),
      vadSilenceMs: json['vad_silence_ms'] ?? 1500,
    );
  }

  Map<String, dynamic> toJson() => {
    'model_path': modelPath,
    'provider': provider,
    'api_key': apiKey,
    'llm_model': llmModel,
    'output_dir': outputDir,
    'mode': mode,
    'obsidian_vault_path': obsidianVaultPath,
    'persona': persona,
    'research': research,
    'github_token': githubToken,
    'github_repo': githubRepo,
    'gitlab_token': gitlabToken,
    'gitlab_repo': gitlabRepo,
    'vad_threshold': vadThreshold,
    'vad_silence_ms': vadSilenceMs,
  };

  Config copyWith({
    String? modelPath,
    String? provider,
    String? apiKey,
    String? llmModel,
    String? outputDir,
    String? mode,
    String? obsidianVaultPath,
    String? persona,
    bool? research,
    String? githubToken,
    String? githubRepo,
    String? gitlabToken,
    String? gitlabRepo,
    double? vadThreshold,
    int? vadSilenceMs,
  }) {
    return Config(
      modelPath: modelPath ?? this.modelPath,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      llmModel: llmModel ?? this.llmModel,
      outputDir: outputDir ?? this.outputDir,
      mode: mode ?? this.mode,
      obsidianVaultPath: obsidianVaultPath ?? this.obsidianVaultPath,
      persona: persona ?? this.persona,
      research: research ?? this.research,
      githubToken: githubToken ?? this.githubToken,
      githubRepo: githubRepo ?? this.githubRepo,
      gitlabToken: gitlabToken ?? this.gitlabToken,
      gitlabRepo: gitlabRepo ?? this.gitlabRepo,
      vadThreshold: vadThreshold ?? this.vadThreshold,
      vadSilenceMs: vadSilenceMs ?? this.vadSilenceMs,
    );
  }
}
