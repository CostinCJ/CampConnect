import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';
import '../../map/domain/location.dart';
import '../domain/passport_stamp.dart';

/// Grid of all session locations; visited ones carry a stamp, and a perfect
/// quiz score earns a star. All state is device-local.
class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final locationsAsync = ref.watch(resolvedSessionLocationsProvider);
    final stamps = ref.watch(passportProvider).valueOrNull ?? const [];
    final quizResults = ref.watch(quizResultsProvider).valueOrNull ?? const {};
    final stampByLocation = {for (final s in stamps) s.locationId: s};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.explorerPassport)),
      body: locationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.somethingWentWrong),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(resolvedSessionLocationsProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (locations) {
          if (locations.isEmpty) {
            // No live camp locations to join against — either the kid is
            // signed out (lost/expired code) or the camp is gone. Earned
            // stamps must still show, so fall back to the names/categories
            // denormalized into the stamps at check-in time.
            if (stamps.isNotEmpty) {
              return _StampsOnlyGrid(stamps: stamps, quizResults: quizResults);
            }
            return EmptyState(
              icon: Icons.approval_outlined,
              title: l10n.noStampsYet,
            );
          }
          final total = locations.length;
          final count = locations
              .where((r) => stampByLocation.containsKey(r.masterLocation.id))
              .length;
          final dateFormat = DateFormat(
            'd MMM',
            Localizations.localeOf(context).toString(),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: SectionHeader(l10n.stampsProgress(count, total)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final resolved = locations[index];
                    final master = resolved.masterLocation;
                    final stamp = stampByLocation[master.id];
                    final visited = stamp != null;
                    final perfectQuiz =
                        quizResults[master.id]?.isPerfect ?? false;
                    final accent = master.category.color;

                    return Card(
                      color: visited
                          ? Color.alphaBlend(
                              accent.withValues(alpha: 0.14),
                              theme.cardTheme.color!,
                            )
                          : theme.cardTheme.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: visited
                            ? BorderSide(color: accent, width: 2)
                            : BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconBubble(
                                  icon: visited
                                      ? Icons.verified
                                      : master.category.icon,
                                  size: 48,
                                  background: accent.withValues(
                                    alpha: visited ? 0.2 : 0.08,
                                  ),
                                  foreground: visited
                                      ? accent
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                if (perfectQuiz)
                                  const Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Icon(
                                      Icons.star,
                                      size: 20,
                                      color: Color(0xFFFFC107),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              master.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (visited) ...[
                              const SizedBox(height: 4),
                              Text(
                                dateFormat.format(stamp.visitedAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Passport rendered purely from the stamps saved on this device — used when
/// the live camp-location join is unavailable (signed out after losing a
/// code, or the camp session no longer exists). Every card here is a visited
/// one by definition; stamps from before name denormalization existed get a
/// generic label.
class _StampsOnlyGrid extends StatelessWidget {
  final List<PassportStamp> stamps;
  final Map<String, QuizResult> quizResults;

  const _StampsOnlyGrid({required this.stamps, required this.quizResults});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final dateFormat = DateFormat(
      'd MMM',
      Localizations.localeOf(context).toString(),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: SectionHeader(l10n.stampsCollected(stamps.length)),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: stamps.length,
            itemBuilder: (context, index) {
              final stamp = stamps[index];
              final category = LocationCategory.values
                  .where((c) => c.name == stamp.categoryName)
                  .firstOrNull;
              final accent = category?.color ?? theme.colorScheme.primary;
              final perfectQuiz =
                  quizResults[stamp.locationId]?.isPerfect ?? false;

              return Card(
                color: Color.alphaBlend(
                  accent.withValues(alpha: 0.14),
                  theme.cardTheme.color!,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: accent, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconBubble(
                            icon: Icons.verified,
                            size: 48,
                            background: accent.withValues(alpha: 0.2),
                            foreground: accent,
                          ),
                          if (perfectQuiz)
                            const Positioned(
                              top: -4,
                              right: -4,
                              child: Icon(
                                Icons.star,
                                size: 20,
                                color: Color(0xFFFFC107),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        stamp.locationName ?? l10n.campLocationFallback,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(stamp.visitedAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
