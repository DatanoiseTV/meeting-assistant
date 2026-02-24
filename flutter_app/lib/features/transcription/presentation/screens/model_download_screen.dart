import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/model_download_provider.dart';

class ModelDownloadScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const ModelDownloadScreen({super.key, required this.onComplete});

  @override
  ConsumerState<ModelDownloadScreen> createState() =>
      _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(modelDownloadProvider.notifier).checkAndDownloadModel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(modelDownloadProvider);

    ref.listen<ModelDownloadState>(modelDownloadProvider, (previous, next) {
      if (next.status == ModelDownloadStatus.completed) {
        widget.onComplete();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(
                Icons.download_for_offline_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Downloading Whisper Model',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'The first run requires downloading the Whisper medium model (~500MB). This may take a few minutes depending on your internet connection.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _buildProgressContent(context, downloadState),
              const Spacer(),
              if (downloadState.status == ModelDownloadStatus.error)
                Column(
                  children: [
                    Text(
                      'Error: ${downloadState.errorMessage}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref
                            .read(modelDownloadProvider.notifier)
                            .checkAndDownloadModel();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressContent(BuildContext context, ModelDownloadState state) {
    switch (state.status) {
      case ModelDownloadStatus.idle:
      case ModelDownloadStatus.checking:
        return const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking model...'),
          ],
        );

      case ModelDownloadStatus.downloading:
        return Column(
          children: [
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${(state.progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Downloading medium model...'),
          ],
        );

      case ModelDownloadStatus.completed:
        return const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 16),
            Text('Model ready!'),
          ],
        );

      case ModelDownloadStatus.error:
        return const SizedBox();
    }
  }
}
