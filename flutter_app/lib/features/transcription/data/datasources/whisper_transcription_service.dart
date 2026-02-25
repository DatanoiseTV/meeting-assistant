import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

class WhisperTranscriptionService {
  Whisper? _whisper;
  bool _isInitialized = false;
  WhisperModel _currentModel = WhisperModel.tiny;

  bool isDownloading = false;
  double downloadProgress = 0.0; // 0.0 – 1.0
  void Function(double)? onDownloadProgress;

  bool get isInitialized => _isInitialized;

  static WhisperModel modelFromString(String name) {
    switch (name) {
      case 'tiny':
        return WhisperModel.tiny;
      case 'base':
        return WhisperModel.base;
      case 'small':
        return WhisperModel.small;
      case 'medium':
        return WhisperModel.medium;
      case 'large-v1':
        return WhisperModel.largeV1;
      case 'large-v2':
        return WhisperModel.largeV2;
      default:
        return WhisperModel.tiny;
    }
  }

  Future<String> _getModelDir() async {
    final dir = Platform.isAndroid
        ? await getApplicationSupportDirectory()
        : await getLibraryDirectory();
    return dir.path;
  }

  // Download the model file with progress reporting if not already present.
  Future<void> _ensureModel(WhisperModel model, String downloadHost) async {
    final modelDir = await _getModelDir();
    final modelFile = File('$modelDir/ggml-${model.modelName}.bin');
    if (modelFile.existsSync()) {
      debugPrint('[Whisper] Model already cached: ${modelFile.path}');
      return;
    }

    debugPrint('[Whisper] Downloading model ${model.modelName}...');
    isDownloading = true;
    downloadProgress = 0.0;
    onDownloadProgress?.call(0.0);

    final uri = Uri.parse('$downloadHost/ggml-${model.modelName}.bin');
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();

      final total = response.contentLength;
      int received = 0;

      final raf = modelFile.openSync(mode: FileMode.write);
      await for (final chunk in response) {
        raf.writeFromSync(chunk);
        received += chunk.length;
        if (total > 0) {
          downloadProgress = received / total;
          onDownloadProgress?.call(downloadProgress);
        }
      }
      await raf.close();
      debugPrint('[Whisper] Download complete: ${modelFile.path}');
    } catch (e) {
      if (modelFile.existsSync()) modelFile.deleteSync();
      rethrow;
    } finally {
      isDownloading = false;
      downloadProgress = 0.0;
      onDownloadProgress?.call(-1.0); // -1 signals completion
      client.close();
    }
  }

  Future<void> initialize({
    String modelName = 'tiny',
    String? customDownloadHost,
    void Function(double progress)? onProgress,
  }) async {
    final model = modelFromString(modelName);
    if (_isInitialized && _currentModel == model) return;

    _currentModel = model;
    onDownloadProgress = onProgress;

    final downloadHost =
        customDownloadHost ??
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main";

    await _ensureModel(model, downloadHost);

    _whisper = Whisper(model: model, downloadHost: downloadHost);

    try {
      final version = await _whisper!.getVersion();
      debugPrint('[Whisper] Initialized with model=$modelName: $version');
      _isInitialized = true;
    } catch (e) {
      debugPrint('[Whisper] Init failed: $e');
      rethrow;
    }
  }

  // Convert a locale string like "en_US" to a Whisper ISO 639-1 code like "en".
  static String _toWhisperLang(String locale) {
    if (locale == 'auto') return 'auto';
    return locale.split('_').first.toLowerCase();
  }

  Future<String> transcribe({
    required String audioPath,
    String language = 'auto',
    bool translateToEnglish = false,
    bool withTimestamps = false,
  }) async {
    if (!_isInitialized || _whisper == null) {
      await initialize(modelName: _currentModel.modelName);
    }

    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('[Whisper] Audio file not found: $audioPath');
    }
    final size = await file.length();
    debugPrint('[Whisper] Transcribing: $audioPath ($size bytes)');

    final whisperLang = _toWhisperLang(language);
    debugPrint('[Whisper] Language: $whisperLang');

    final request = TranscribeRequest(
      audio: audioPath,
      language: whisperLang,
      isTranslate: translateToEnglish,
      isNoTimestamps: !withTimestamps,
      splitOnWord: false,
    );

    try {
      final WhisperTranscribeResponse result = await _whisper!.transcribe(
        transcribeRequest: request,
      );
      debugPrint('[Whisper] Result: "${result.text}"');
      return result.text;
    } catch (e) {
      debugPrint('[Whisper] Transcription error: $e');
      rethrow;
    }
  }

  void dispose() {
    _whisper = null;
    _isInitialized = false;
  }
}
