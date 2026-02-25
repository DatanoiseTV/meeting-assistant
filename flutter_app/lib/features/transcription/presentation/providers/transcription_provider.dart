import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/datasources/whisper_service.dart';
import '../../data/datasources/whisper_transcription_service.dart';
import '../../domain/entities/meeting.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

final whisperServiceProvider = Provider<WhisperService>((ref) {
  final service = WhisperService();
  ref.onDispose(() {});
  return service;
});

final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = AudioRecordingService();
  ref.onDispose(() => service.dispose());
  return service;
});

final whisperTranscriptionServiceProvider =
    Provider<WhisperTranscriptionService>((ref) {
      final service = WhisperTranscriptionService();
      ref.onDispose(() => service.dispose());
      return service;
    });

final transcriptionProvider =
    StateNotifierProvider<TranscriptionNotifier, TranscriptionState>((ref) {
      final speechService = ref.watch(whisperServiceProvider);
      final audioService = ref.watch(audioRecordingServiceProvider);
      final whisperOfflineService = ref.watch(
        whisperTranscriptionServiceProvider,
      );

      // Pass ref so the notifier can read settings dynamically at call time
      return TranscriptionNotifier(
        speechService,
        audioService,
        whisperOfflineService,
        ref,
      );
    });

class TranscriptionNotifier extends StateNotifier<TranscriptionState> {
  final WhisperService _speechService;
  final AudioRecordingService _audioService;
  final WhisperTranscriptionService _whisperOfflineService;
  final Ref _ref;
  DateTime? _recordingStartTime;
  Timer? _transcribingTimer;

  TranscriptionNotifier(
    this._speechService,
    this._audioService,
    this._whisperOfflineService,
    this._ref,
  ) : super(const TranscriptionState());

  bool get _useWhisper {
    return _ref.read(settingsProvider).value?.useWhisper ?? false;
  }

  String get _localeId {
    return _ref.read(settingsProvider).value?.speechLanguage ?? 'en_US';
  }

  void _startTranscribingTimer() {
    _transcribingTimer?.cancel();
    int elapsed = 0;
    _transcribingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed++;
      if (mounted) {
        state = state.copyWith(transcribingElapsedSeconds: elapsed);
      }
    });
  }

  void _stopTranscribingTimer() {
    _transcribingTimer?.cancel();
    _transcribingTimer = null;
  }

  Future<void> initializeWhisper() async {
    state = state.copyWith(status: TranscriptionStatus.processing);
    try {
      await _speechService.initialize();
      state = state.copyWith(status: TranscriptionStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: TranscriptionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> startRecording() async {
    try {
      final hasPermission = await _audioService.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(
          status: TranscriptionStatus.error,
          errorMessage: 'Microphone permission denied',
        );
        return;
      }

      _recordingStartTime = DateTime.now();
      state = state.copyWith(
        status: TranscriptionStatus.recording,
        transcription: '',
      );

      if (_useWhisper) {
        // Offline mode: record audio to file, transcribe after stopping
        await _audioService.startRecording();
      } else {
        // Live mode: stream speech recognition
        _speechService.setLocale(_localeId);
        await _speechService.initialize();
        await _startLiveSpeechRecognition();
      }
    } catch (e) {
      state = state.copyWith(
        status: TranscriptionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _startLiveSpeechRecognition() async {
    _speechService.setOnDoneCallback(null);

    await _speechService.startListening(
      onResult: (text) {
        if (mounted) {
          state = state.copyWith(transcription: text);
        }
      },
      onError: (error) {
        if (mounted) {
          state = state.copyWith(
            status: TranscriptionStatus.error,
            errorMessage: 'Speech recognition failed: $error',
          );
        }
      },
      onDone: () {
        if (mounted &&
            state.status == TranscriptionStatus.recording &&
            state.transcription.isNotEmpty) {
          print('Speech recognition ended - transcription preserved');
        }
      },
    );
  }

  Future<void> stopRecording() async {
    try {
      int? durationSeconds;
      if (_recordingStartTime != null) {
        durationSeconds = DateTime.now()
            .difference(_recordingStartTime!)
            .inSeconds;
        _recordingStartTime = null;
      }

      if (_useWhisper) {
        // Offline mode: stop recording, then run whisper transcription
        state = state.copyWith(status: TranscriptionStatus.transcribing);

        final audioPath = await _audioService.stopRecording();
        debugPrint('[Whisper] Audio path after stop: $audioPath');
        if (audioPath == null) {
          state = state.copyWith(
            status: TranscriptionStatus.error,
            errorMessage: 'No audio recorded',
          );
          return;
        }

        final locale = _localeId;
        final modelName =
            _ref.read(settingsProvider).value?.whisperModel ?? 'tiny';
        debugPrint('[Whisper] Using locale: $locale, model: $modelName');

        // Ensure the correct model is initialized (re-init if model changed),
        // relaying download progress into state so the UI can show a bar.
        await _whisperOfflineService.initialize(
          modelName: modelName,
          onProgress: (p) {
            if (mounted) {
              state = state.copyWith(modelDownloadProgress: p);
            }
          },
        );

        _startTranscribingTimer();
        try {
          final transcription = await _whisperOfflineService.transcribe(
            audioPath: audioPath,
            language: locale,
          );
          _stopTranscribingTimer();
          debugPrint('[Whisper] Final transcription: "$transcription"');
          state = state.copyWith(
            status: TranscriptionStatus.completed,
            transcription: transcription,
            transcribingElapsedSeconds: 0,
          );
          // Clean up audio file after transcription
          try {
            await File(audioPath).delete();
          } catch (_) {}
        } catch (e) {
          _stopTranscribingTimer();
          debugPrint('[Whisper] stopRecording transcription error: $e');
          state = state.copyWith(
            status: TranscriptionStatus.error,
            errorMessage: 'Whisper transcription failed: $e',
          );
        }
      } else {
        // Live mode: stop speech recognition
        await _speechService.stopListening();
        final transcription = _speechService.fullTranscription;

        state = state.copyWith(
          status: TranscriptionStatus.completed,
          transcription: transcription,
        );
        print(
          'Recording complete: ${transcription.length} chars, duration: ${durationSeconds}s',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: TranscriptionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void cancelRecording() {
    if (_useWhisper) {
      _audioService.cancelRecording();
    } else {
      _speechService.stopListening();
    }
    _recordingStartTime = null;
    state = state.copyWith(status: TranscriptionStatus.idle);
  }

  Future<void> importTranscriptFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'txt',
          'text',
          'm4a',
          'mp3',
          'wav',
          'aac',
          'mp4',
          'mov',
        ],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      state = state.copyWith(status: TranscriptionStatus.processing);

      if (file.extension == 'txt' || file.extension == 'text') {
        // Read text file directly
        final bytes = file.bytes;
        if (bytes != null) {
          final content = String.fromCharCodes(bytes);
          state = state.copyWith(
            status: TranscriptionStatus.completed,
            transcription: content,
          );
          return;
        }

        // Try reading from path
        if (file.path != null) {
          final content = await File(file.path!).readAsString();
          state = state.copyWith(
            status: TranscriptionStatus.completed,
            transcription: content,
          );
          return;
        }
      }

      // For audio files, show message that transcription requires manual processing
      // or implement audio transcription service
      state = state.copyWith(
        status: TranscriptionStatus.error,
        errorMessage:
            'Audio file import requires transcription service. Please use microphone to record.',
      );
    } catch (e) {
      state = state.copyWith(
        status: TranscriptionStatus.error,
        errorMessage: 'Failed to import file: $e',
      );
    }
  }

  void reset() {
    _recordingStartTime = null;
    state = const TranscriptionState();
  }

  @override
  void dispose() {
    _transcribingTimer?.cancel();
    super.dispose();
  }
}
