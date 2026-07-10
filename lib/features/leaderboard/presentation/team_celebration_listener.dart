import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';
import 'package:camp_connect/shared/widgets/confetti_burst.dart';
import '../domain/celebration.dart';
import '../domain/team.dart';

/// Watches the leaderboard and fires a celebratory overlay when the kid's
/// own team gains points or climbs a rank. Mirrors the guide shell's
/// EmergencyAlertListener placement pattern. The first emission after mount
/// is the baseline and never celebrates (prevents replay on app open).
class TeamCelebrationListener extends ConsumerStatefulWidget {
  final Widget child;

  const TeamCelebrationListener({super.key, required this.child});

  @override
  ConsumerState<TeamCelebrationListener> createState() =>
      _TeamCelebrationListenerState();
}

class _TeamCelebrationListenerState
    extends ConsumerState<TeamCelebrationListener> {
  List<Team>? _previous;
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Team>>>(leaderboardProvider, (prev, next) {
      final current = next.valueOrNull;
      if (current == null) return;
      final previous = _previous;
      _previous = current;
      if (previous == null || _showing) return;

      final teamId = ref.read(appUserProvider).valueOrNull?.team;
      final celebration = detectCelebration(
        previous: previous,
        current: current,
        teamId: teamId,
      );
      if (celebration == null) return;

      final teams = current;
      final team = teams.where((t) => t.id == teamId).firstOrNull;
      _showing = true;
      showDialog<void>(
        context: context,
        barrierColor: Colors.black26,
        builder: (ctx) => _CelebrationOverlay(
          celebration: celebration,
          teamColor: team?.color ?? Theme.of(ctx).colorScheme.primary,
        ),
      ).whenComplete(() => _showing = false);
    });

    return widget.child;
  }
}

class _CelebrationOverlay extends StatefulWidget {
  final Celebration celebration;
  final Color teamColor;

  const _CelebrationOverlay({
    required this.celebration,
    required this.teamColor,
  });

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay> {
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _autoClose = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final c = widget.celebration;
    final onTeamColor = HeroCard.onColor(widget.teamColor);

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: ConfettiBurst(color: widget.teamColor)),
          Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: widget.teamColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    c.isRankUp ? Icons.military_tech : Icons.emoji_events,
                    size: 56,
                    color: onTeamColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.isRankUp
                        ? l10n.teamCelebrationRankUp(c.newRank)
                        : l10n.teamCelebrationPoints(c.pointsDelta),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: onTeamColor),
                  ),
                  if (c.isRankUp && c.pointsDelta > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.teamCelebrationPoints(c.pointsDelta),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onTeamColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
