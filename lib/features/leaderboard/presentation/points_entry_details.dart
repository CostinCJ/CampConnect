import 'package:flutter/material.dart';

import 'package:camp_connect/core/theme/app_theme.dart';
import 'package:camp_connect/core/utils/relative_time.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';
import '../domain/points_entry.dart';

/// Full-detail dialog for a points-history entry, so long reasons that get
/// ellipsized in list tiles can be read in full.
Future<void> showPointsEntryDetails(
  BuildContext context, {
  required PointsEntry entry,
  required String teamName,
  required Color teamColor,
}) {
  final theme = Theme.of(context);
  final l10n = AppL10n.of(context);
  final camp = theme.extension<CampColors>()!;
  final isPositive = entry.amount >= 0;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(teamName, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          StatPill(
            label: '${isPositive ? '+' : ''}${entry.amount} ${l10n.pts}',
            background: isPositive
                ? theme.colorScheme.primaryContainer
                : camp.sunsetSoft,
            foreground: isPositive
                ? theme.colorScheme.onPrimaryContainer
                : camp.onSunsetSoft,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.reason.isNotEmpty ? entry.reason : '-',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              relativeTime(l10n, entry.timestamp),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok)),
      ],
    ),
  );
}
