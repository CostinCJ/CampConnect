// lib/features/map/presentation/widgets/location_detail_sheet.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class LocationDetailSheet extends ConsumerStatefulWidget {
  final Location location;

  const LocationDetailSheet({super.key, required this.location});

  @override
  ConsumerState<LocationDetailSheet> createState() => _LocationDetailSheetState();
}

class _LocationDetailSheetState extends ConsumerState<LocationDetailSheet> {
  bool _quizAnswerRevealed = false;

  void _deleteLocation() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteLocation),
        content: Text(l10n.deleteLocationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final campId = ref.read(activeCampIdProvider);
    if (campId == null) return;

    try {
      // Delete photo from Storage if exists
      if (widget.location.photoUrl != null) {
        await ref.read(imageUploadServiceProvider).deleteImage(widget.location.photoUrl!);
      }
      // Delete Firestore document
      await ref.read(locationRepositoryProvider).deleteLocation(campId, widget.location.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.locationDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.somethingWentWrong)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final location = widget.location;
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final isGuide = appUser?.isGuide ?? false;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: name + guide actions
              Row(
                children: [
                  Icon(location.category.icon, color: location.category.color, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      location.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isGuide) ...[
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/guide/map/edit', extra: widget.location);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _deleteLocation,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Category badge
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(location.category.icon, size: 16, color: location.category.color),
                  label: Text(_categoryLabel(l10n, location.category)),
                  backgroundColor: location.category.color.withValues(alpha: 0.1),
                  side: BorderSide.none,
                ),
              ),
              const SizedBox(height: 12),

              // Photo
              if (location.photoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: location.photoUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      height: 200,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, _, _) => Container(
                      height: 200,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
              if (location.photoUrl != null) const SizedBox(height: 16),

              // Description
              Text(
                location.description,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),

              // Facts
              if (location.facts.isNotEmpty) ...[
                Text(
                  l10n.facts,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...location.facts.map((fact) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('  \u2022  '),
                      Expanded(child: Text(fact, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
              ],

              // Fun Fact
              if (location.funFact.isNotEmpty)
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb, color: theme.colorScheme.tertiary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.funFact,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.tertiary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(location.funFact, style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (location.funFact.isNotEmpty) const SizedBox(height: 16),

              // Quiz
              if (location.quizQuestion != null && location.quizQuestion!.isNotEmpty) ...[
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.quiz, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              l10n.quiz,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(location.quizQuestion!, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        if (_quizAnswerRevealed && location.quizAnswer != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              location.quizAnswer!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else if (location.quizAnswer != null)
                          TextButton.icon(
                            onPressed: () => setState(() => _quizAnswerRevealed = true),
                            icon: const Icon(Icons.visibility),
                            label: Text(l10n.revealAnswer),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Placeholder for LLM (Phase 6)
              // Phase 6 — "Ask AI" button goes here
            ],
          ),
        );
      },
    );
  }

  String _categoryLabel(AppLocalizations l10n, LocationCategory cat) {
    switch (cat) {
      case LocationCategory.nature:
        return l10n.categoryNature;
      case LocationCategory.historical:
        return l10n.categoryHistorical;
    }
  }
}
