import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/datasources/whisper_service.dart';
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

final transcriptionProvider =
    StateNotifierProvider<TranscriptionNotifier, TranscriptionState>((ref) {
      final whisperService = ref.watch(whisperServiceProvider);
      final audioService = ref.watch(audioRecordingServiceProvider);
      final settings = ref.watch(settingsProvider);

      String localeId = 'en_US';
      settings.whenData((config) {
        localeId = config.speechLanguage;
      });

      whisperService.setLocale(localeId);

      return TranscriptionNotifier(whisperService, audioService);
    });

class TranscriptionNotifier extends StateNotifier<TranscriptionState> {
  final WhisperService _whisperService;
  final AudioRecordingService _audioService;
  DateTime? _recordingStartTime;

  TranscriptionNotifier(this._whisperService, this._audioService)
    : super(const TranscriptionState());

  Future<void> initializeWhisper() async {
    state = state.copyWith(status: TranscriptionStatus.processing);
    try {
      await _whisperService.initialize();
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

      await _whisperService.initialize();
      _recordingStartTime = DateTime.now();

      state = state.copyWith(
        status: TranscriptionStatus.recording,
        transcription: '',
      );

      await _startListeningWithAutoRestart();
    } catch (e) {
      state = state.copyWith(
        status: TranscriptionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _startListeningWithAutoRestart() async {
    _whisperService.setOnDoneCallback(null);

    await _whisperService.startListening(
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
        // Only restart if we're still supposed to be recording
        // and there's transcription data
        if (mounted &&
            state.status == TranscriptionStatus.recording &&
            state.transcription.isNotEmpty) {
          // Don't auto-restart - just keep the transcription
          // iOS will timeout after ~60 seconds of continuous speech
          // The user should manually stop when done
          print('Speech recognition ended - transcription preserved');
        }
      },
    );
  }

  Future<void> stopRecording() async {
    try {
      await _whisperService.stopListening();

      final transcription = _whisperService.fullTranscription;

      int? durationSeconds;
      if (_recordingStartTime != null) {
        durationSeconds = DateTime.now()
            .difference(_recordingStartTime!)
            .inSeconds;
        _recordingStartTime = null;
      }

      state = state.copyWith(
        status: TranscriptionStatus.completed,
        transcription: transcription,
      );

      // Meeting will be created when navigating to the meeting detail
      print(
        'Recording complete: ${transcription.length} chars, duration: ${durationSeconds}s',
      );
    } catch (e) {
      state = state.copyWith(
        status: TranscriptionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void cancelRecording() {
    _whisperService.stopListening();
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
    super.dispose();
  }
}
