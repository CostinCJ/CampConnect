import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import '../domain/journal_entry.dart';

class JournalDetailScreen extends ConsumerWidget {
  final JournalEntry entry;

  const JournalDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', l10n.locale);

    // Watch journal state to get the latest version of this entry
    final journalState = ref.watch(journalProvider);
    final currentEntry = journalState.whenOrNull(
          data: (entries) {
            try {
              return entries.firstWhere((e) => e.id == entry.id);
            } catch (_) {
              return null;
            }
          },
        ) ??
        entry;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l10n.editEntry,
            onPressed: () =>
                context.push('/kid/journal/edit', extra: currentEntry),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.deleteEntry,
            onPressed: () => _confirmDelete(context, ref, l10n),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date
            Text(
              dateFormat.format(currentEntry.date),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              currentEntry.title,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // Photos
            if (currentEntry.photos.isNotEmpty) ...[
              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: currentEntry.photos.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right:
                            index < currentEntry.photos.length - 1 ? 12 : 0,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(currentEntry.photos[index]),
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => Container(
                            width: 200,
                            height: 220,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Body
            Text(
              currentEntry.body,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteEntry),
        content: Text(l10n.deleteEntryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(journalProvider.notifier).deleteEntry(entry.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.entryDeleted)),
                );
                context.pop();
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
