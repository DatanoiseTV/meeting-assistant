import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class RecordButton extends ConsumerStatefulWidget {
  final TranscriptionState state;

  const RecordButton({super.key, required this.state});

  @override
  ConsumerState<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends ConsumerState<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isRecording = widget.state.status == TranscriptionStatus.recording;
    final wasRecording =
        oldWidget.state.status == TranscriptionStatus.recording;

    if (isRecording && !wasRecording) {
      _controller.repeat();
    } else if (!isRecording && wasRecording) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = widget.state.status == TranscriptionStatus.recording;
    final isProcessing =
        widget.state.status == TranscriptionStatus.processing ||
        widget.state.status == TranscriptionStatus.transcribing;

    return GestureDetector(
      onTap: isProcessing ? null : () => _handleTap(context),
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isRecording)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(
                          alpha: _opacityAnimation.value,
                        ),
                      ),
                    ),
                  );
                },
              ),
            AnimatedContainer(
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
                            .withValues(alpha: 0.4),
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
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (widget.state.status == TranscriptionStatus.recording) {
      ref.read(transcriptionProvider.notifier).stopRecording();
    } else {
      ref.read(transcriptionProvider.notifier).startRecording();
    }
  }
}
