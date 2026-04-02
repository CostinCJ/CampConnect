import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import '../domain/journal_entry.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final journalState = ref.watch(journalProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.journal),
        actions: [
          journalState.whenOrNull(
                data: (entries) => entries.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.picture_as_pdf),
                        tooltip: l10n.exportPdf,
                        onPressed: () => context.push('/kid/journal/export'),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: journalState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.somethingWentWrong),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.read(journalProvider.notifier).loadEntries(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (entries) => entries.isEmpty
            ? _EmptyState(l10n: l10n, theme: theme)
            : _EntryList(entries: entries, l10n: l10n, theme: theme),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/kid/journal/new'),
        child: const Icon(Icons.edit),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  const _EmptyState({required this.l10n, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noJournalEntries,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.startWriting,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  final List<JournalEntry> entries;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _EntryList({
    required this.entries,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _JournalEntryCard(
          entry: entry,
          l10n: l10n,
          theme: theme,
          onTap: () => context.push('/kid/journal/view', extra: entry),
        );
      },
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onTap;

  const _JournalEntryCard({
    required this.entry,
    required this.l10n,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', l10n.locale);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              if (entry.photos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Image.file(
                        File(entry.photos.first),
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(entry.date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (entry.photos.length > 1) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.photos.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
