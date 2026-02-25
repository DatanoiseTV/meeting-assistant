import 'dart:async';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

class TranscriptionSegment {
  final String text;
  final double startTime;
  final double endTime;

  TranscriptionSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}

enum TranscriptionStatus {
  idle,
  recording,
  processing,
  transcribing,
  completed,
  error,
}

class TranscriptionState {
  final TranscriptionStatus status;
  final String transcription;
  final List<TranscriptionSegment> segments;
  final double audioLevel;
  final String? errorMessage;
  final int progress;
  final int transcribingElapsedSeconds;
  // Download progress: -1 = not downloading, 0.0-1.0 = downloading
  final double modelDownloadProgress;

  const TranscriptionState({
    this.status = TranscriptionStatus.idle,
    this.transcription = '',
    this.segments = const [],
    this.audioLevel = 0.0,
    this.errorMessage,
    this.progress = 0,
    this.transcribingElapsedSeconds = 0,
    this.modelDownloadProgress = -1.0,
  });

  bool get isDownloadingModel => modelDownloadProgress >= 0.0;

  TranscriptionState copyWith({
    TranscriptionStatus? status,
    String? transcription,
    List<TranscriptionSegment>? segments,
    double? audioLevel,
    String? errorMessage,
    int? progress,
    int? transcribingElapsedSeconds,
    double? modelDownloadProgress,
  }) {
    return TranscriptionState(
      status: status ?? this.status,
      transcription: transcription ?? this.transcription,
      segments: segments ?? this.segments,
      audioLevel: audioLevel ?? this.audioLevel,
      errorMessage: errorMessage,
      progress: progress ?? this.progress,
      transcribingElapsedSeconds:
          transcribingElapsedSeconds ?? this.transcribingElapsedSeconds,
      modelDownloadProgress:
          modelDownloadProgress ?? this.modelDownloadProgress,
    );
  }
}

class WhisperService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _fullTranscription = '';
  String _localeId = 'en_US';
  void Function(String)? _currentResultCallback;
  void Function(String)? _errorCallback;
  void Function()? _onDone;
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get isListening => _isListening;

  void setLocale(String localeId) {
    _localeId = localeId;
  }

  void setOnDoneCallback(void Function()? callback) {
    _onDone = callback;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _fullTranscription = '';
    _hasError = false;
    _errorMessage = '';

    try {
      await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            if (_fullTranscription.isNotEmpty) {
              _onDone?.call();
            }
          }
        },
        onError: (error) {
          print('Speech error: $error');
          _hasError = true;
          _errorMessage = error.errorMsg;
          _errorCallback?.call(error.errorMsg);
          _isListening = false;
        },
      );
      _isInitialized = true;
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> startListening({
    required void Function(String text) onResult,
    void Function(String error)? onError,
    void Function()? onDone,
  }) async {
    _currentResultCallback = onResult;
    _errorCallback = onError;
    _onDone = onDone;
    _fullTranscription = '';
    _hasError = false;
    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        _fullTranscription = result.recognizedWords;
        _currentResultCallback?.call(_fullTranscription);
        if (result.finalResult) {
          _isListening = false;
          _onDone?.call();
        }
      },
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 30),
      localeId: _localeId,
      cancelOnError: false,
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
  }

  String get fullTranscription => _fullTranscription;
}

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String> startRecording() async {
    if (_isRecording) return _currentRecordingPath!;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingPath = '${directory.path}/recording_$timestamp.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _currentRecordingPath!,
    );

    _isRecording = true;
    return _currentRecordingPath!;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;
    return path;
  }

  void cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
      _currentRecordingPath = null;
    }
  }

  Stream<double> get amplitudeStream {
    return _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).map((
      amp,
    ) {
      final normalized = (amp.current + 60) / 60;
      return normalized.clamp(0.0, 1.0);
    });
  }

  void dispose() {
    _recorder.dispose();
  }
}

class AudioLevelSimulator {
  static double simulateLevel() {
    return 0.3 + Random().nextDouble() * 0.4;
  }
}
