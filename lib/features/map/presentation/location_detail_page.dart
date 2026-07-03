// lib/features/map/presentation/location_detail_page.dart
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/llm/data/llm_runtime.dart';
import 'package:camp_connect/features/llm/presentation/llm_chat_widget.dart';
import 'package:camp_connect/features/llm/presentation/start_chat_button.dart';
import 'package:camp_connect/features/llm/providers/llm_providers.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class LocationDetailPage extends ConsumerStatefulWidget {
  final Location masterLocation;
  final String? groupPhotoUrl;

  const LocationDetailPage({
    super.key,
    required this.masterLocation,
    this.groupPhotoUrl,
  });

  @override
  ConsumerState<LocationDetailPage> createState() =>
      _LocationDetailPageState();
}

class _LocationDetailPageState extends ConsumerState<LocationDetailPage> {
  bool _chatActive = false;

  Future<void> _startChat() async {
    // Check the model file directly don't create LlmRuntime() here
    // because its LlamaController constructor steals the Pigeon callback
    // from the real controller in llmRuntimeProvider.
    final docsDir = await getApplicationDocumentsDirectory();
    final modelPath = '${docsDir.path}/${AppConstants.llmModelFileName}';
    final modelExists = File(modelPath).existsSync();
    debugPrint('[LLM] _startChat: modelPath=$modelPath, exists=$modelExists');
    if (!modelExists) {
      ref.read(settingsProvider.notifier).setModelDownloaded(false);
      ref.read(modelDownloadProvider.notifier).startDownload();
      debugPrint('[LLM] _startChat: model not found, starting download');
      return;
    }

    // Load the model if it is not ready yet
    final llmState = ref.read(llmRuntimeProvider);
    debugPrint('[LLM] _startChat: llmState=$llmState, calling loadModel');
    if (llmState != LlmState.ready) {
      try {
        await ref.read(llmRuntimeProvider.notifier).loadModel();
      } catch (e) {
        debugPrint('[LLM] _startChat: loadModel failed: $e');
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.llmError),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: l10n.llmRetry,
                onPressed: _startChat,
              ),
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _chatActive = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chatActive) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => setState(() => _chatActive = false),
          ),
          title: Text(widget.masterLocation.name),
        ),
        body: LlmChatWidget(masterLocation: widget.masterLocation),
      );
    }

    return _buildDetailView(context);
  }

  Widget _buildDetailView(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final kb = widget.masterLocation.knowledgeBase;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with hero image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.masterLocation.name,
                style: const TextStyle(
                  shadows: [
                    Shadow(
                      blurRadius: 8,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              background: widget.groupPhotoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: widget.groupPhotoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                            child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Icon(
                            widget.masterLocation.category.icon,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          widget.masterLocation.category.icon,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Category chip
                Wrap(
                  children: [
                    Chip(
                      avatar: Icon(
                        widget.masterLocation.category.icon,
                        size: 18,
                        color: widget.masterLocation.category.color,
                      ),
                      label: Text(
                          _categoryLabel(l10n, widget.masterLocation.category)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                if (widget.masterLocation.description.isNotEmpty) ...[
                  Text(
                    widget.masterLocation.description,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                ],

                // Knowledge base content
                if (!kb.isEmpty) ...[
                  // KB description
                  if (kb.description.isNotEmpty) ...[
                    Text(
                      l10n.knowledgeBaseDescription,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kb.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Facts
                  if (kb.facts.isNotEmpty) ...[
                    Text(
                      l10n.facts,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kb.facts,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Fun fact card
                  if (kb.funFact.isNotEmpty) ...[
                    Card(
                      color: theme.colorScheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb,
                              color:
                                  theme.colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.funFact,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                      color: theme.colorScheme
                                          .onTertiaryContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    kb.funFact,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                      color: theme.colorScheme
                                          .onTertiaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],

                // LLM chat button
                if (settings.llmAvailable)
                  StartChatButton(onStartChat: _startChat),

                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, LocationCategory category) {
    switch (category) {
      case LocationCategory.nature:
        return l10n.categoryNature;
      case LocationCategory.historical:
        return l10n.categoryHistorical;
    }
  }
}
