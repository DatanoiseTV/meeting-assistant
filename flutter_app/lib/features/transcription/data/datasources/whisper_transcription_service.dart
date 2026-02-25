import 'package:whisper_flutter_new/whisper_flutter_new.dart';

class WhisperTranscriptionService {
  Whisper? _whisper;
  bool _isInitialized = false;
  WhisperModel _currentModel = WhisperModel.base;

  bool get isInitialized => _isInitialized;

  Future<void> initialize({
    WhisperModel model = WhisperModel.base,
    String? customDownloadHost,
  }) async {
    if (_isInitialized && _currentModel == model) return;

    _currentModel = model;

    final downloadHost =
        customDownloadHost ??
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main";

    _whisper = Whisper(model: model, downloadHost: downloadHost);

    try {
      final version = await _whisper!.getVersion();
      print('Whisper version: $version');
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize Whisper: $e');
      rethrow;
    }
  }

  Future<String> transcribe({
    required String audioPath,
    String language = 'auto',
    bool translateToEnglish = false,
    bool withTimestamps = false,
  }) async {
    if (!_isInitialized || _whisper == null) {
      await initialize(model: _currentModel);
    }

    final request = TranscribeRequest(
      audio: audioPath,
      language: language,
      isTranslate: translateToEnglish,
      isNoTimestamps: !withTimestamps,
      splitOnWord: false,
    );

    try {
      final WhisperTranscribeResponse result = await _whisper!.transcribe(
        transcribeRequest: request,
      );
      return result.text ?? '';
    } catch (e) {
      print('Transcription error: $e');
      rethrow;
    }
  }

  void dispose() {
    _whisper = null;
    _isInitialized = false;
  }
}
