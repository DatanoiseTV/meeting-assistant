import 'package:flutter_riverpod/flutter_riverpod.dart';

final modelDownloadProvider =
    StateNotifierProvider<ModelDownloadNotifier, ModelDownloadState>((ref) {
      return ModelDownloadNotifier();
    });

enum ModelDownloadStatus { idle, checking, downloading, completed, error }

class ModelDownloadState {
  final ModelDownloadStatus status;
  final double progress;
  final String? errorMessage;
  final bool modelExists;

  const ModelDownloadState({
    this.status = ModelDownloadStatus.idle,
    this.progress = 0.0,
    this.errorMessage,
    this.modelExists = false,
  });

  ModelDownloadState copyWith({
    ModelDownloadStatus? status,
    double? progress,
    String? errorMessage,
    bool? modelExists,
  }) {
    return ModelDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      modelExists: modelExists ?? this.modelExists,
    );
  }
}

class ModelDownloadNotifier extends StateNotifier<ModelDownloadState> {
  ModelDownloadNotifier() : super(const ModelDownloadState());

  Future<void> checkAndDownloadModel() async {
    state = state.copyWith(
      status: ModelDownloadStatus.completed,
      progress: 1.0,
      modelExists: true,
    );
  }

  void reset() {
    state = const ModelDownloadState();
  }
}
