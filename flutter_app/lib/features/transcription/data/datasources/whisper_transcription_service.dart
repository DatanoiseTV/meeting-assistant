import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

class WhisperTranscriptionService {
  Whisper? _whisper;
  bool _isInitialized = false;
  WhisperModel _currentModel = WhisperModel.tiny;

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

  Future<void> initialize({
    String modelName = 'tiny',
    String? customDownloadHost,
  }) async {
    final model = modelFromString(modelName);
    if (_isInitialized && _currentModel == model) return;

    _currentModel = model;

    final downloadHost =
        customDownloadHost ??
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main";

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

  // Convert a locale string like "en_US" or "de_DE" to a Whisper language
  // code like "en" or "de". Whisper expects ISO 639-1 codes or "auto".
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
