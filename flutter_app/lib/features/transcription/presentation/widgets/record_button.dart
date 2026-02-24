import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class RecordButton extends ConsumerWidget {
  final TranscriptionState state;

  const RecordButton({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = state.status == TranscriptionStatus.recording;
    final isProcessing =
        state.status == TranscriptionStatus.processing ||
        state.status == TranscriptionStatus.transcribing;

    return GestureDetector(
      onTap: isProcessing ? null : () => _handleTap(context, ref),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording
              ? Colors.red
              : Theme.of(context).colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color:
                  (isRecording
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary)
                      .withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  size: 48,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    if (state.status == TranscriptionStatus.recording) {
      ref.read(transcriptionProvider.notifier).stopRecording();
    } else {
      ref.read(transcriptionProvider.notifier).startRecording();
    }
  }
}
