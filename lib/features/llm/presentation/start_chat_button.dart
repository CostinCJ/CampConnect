import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/llm/data/llm_runtime.dart';
import 'package:camp_connect/features/llm/providers/llm_providers.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class StartChatButton extends ConsumerWidget {
  final VoidCallback onStartChat;

  const StartChatButton({super.key, required this.onStartChat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    if (!settings.llmAvailable) {
      return const SizedBox.shrink();
    }

    final downloadState = ref.watch(modelDownloadProvider);
    final llmState = ref.watch(llmRuntimeProvider);
    final l10n = AppLocalizations.of(context);

    // Downloading state: show progress indicator
    if (downloadState.status == DownloadStatus.downloading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: downloadState.progress),
          const SizedBox(height: 8),
          Text(l10n.downloadingModel),
        ],
      );
    }

    // Failed state: show error message with retry button
    if (downloadState.status == DownloadStatus.failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.llmError,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () =>
                ref.read(modelDownloadProvider.notifier).startDownload(),
            child: Text(l10n.llmRetry),
          ),
        ],
      );
    }

    // Model loading state: show spinner
    if (llmState == LlmState.loading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(l10n.loadingGuide),
        ],
      );
    }

    // Default state: show start chat button
    return FilledButton.icon(
      onPressed: onStartChat,
      icon: const Icon(Icons.smart_toy),
      label: Text(l10n.startChat),
    );
  }
}
