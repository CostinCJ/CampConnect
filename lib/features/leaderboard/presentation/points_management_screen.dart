import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/l10n/localized_team_names.dart';
import 'package:camp_connect/core/theme/team_colors.dart';
import 'package:camp_connect/core/utils/relative_time.dart';
import 'package:camp_connect/features/auth/domain/camp_session.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/core/theme/app_theme.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';
import '../domain/points_entry.dart';
import '../domain/team.dart';
import 'points_entry_details.dart';

class PointsManagementScreen extends ConsumerStatefulWidget {
  const PointsManagementScreen({super.key});

  @override
  ConsumerState<PointsManagementScreen> createState() =>
      _PointsManagementScreenState();
}

class _PointsManagementScreenState
    extends ConsumerState<PointsManagementScreen> {
  String? _selectedTeam;
  final _pointsController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pointsController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _showTvSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _TvLeaderboardSheet(),
    );
  }

  Future<void> _submitPoints() async {
    final l10n = AppL10n.of(context);
    final campId = ref.read(activeCampIdProvider);
    final appUser = ref.read(appUserProvider).valueOrNull;

    if (_selectedTeam == null || campId == null || appUser == null) return;

    final amount = int.tryParse(_pointsController.text.trim());
    if (amount == null || amount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.invalidPointAmount)));
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enterReason)));
      return;
    }

    // Confirmation dialog
    final teams = ref.read(leaderboardProvider).valueOrNull ?? [];
    final selectedTeamObj = teams
        .where((t) => t.id == _selectedTeam)
        .firstOrNull;
    final teamName = selectedTeamObj?.name ?? _selectedTeam!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmPoints),
        content: Text(
          l10n.confirmPointsMessage(
            amount >= 0 ? l10n.addVerb : l10n.removeVerb,
            amount.abs(),
            amount >= 0 ? l10n.prepositionTo : l10n.prepositionFrom,
            teamName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.submitPoints),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(leaderboardRepositoryProvider)
          .addPoints(
            campId: campId,
            team: _selectedTeam!,
            amount: amount,
            reason: reason,
            addedBy: appUser.displayName,
            teamName: selectedTeamObj?.name ?? '',
            teamColorHex: selectedTeamObj?.colorHex ?? '#9E9E9E',
          );

      if (!mounted) return;

      _pointsController.clear();
      _reasonController.clear();
      // Close the entry form and show the resulting standings.
      setState(() => _selectedTeam = null);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pointsUpdated)));
      context.push('/guide/standings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(leaderboardProvider);
    final historyAsync = ref.watch(pointsHistoryProvider);
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pointsManagement),
        actions: [
          if (ref.watch(activeCampSessionProvider).valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.tv),
              tooltip: l10n.showOnTv,
              onPressed: () => _showTvSheet(context),
            ),
        ],
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.somethingWentWrong),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(leaderboardProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (teams) {
          if (teams.isEmpty) {
            return Center(
              child: Text(
                l10n.noTeamsYet,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // Team selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    l10n.selectTeam,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _TeamSelector(
                  teams: teams,
                  selectedTeam: _selectedTeam,
                  // Tapping the already-selected team toggles the points form
                  // closed again, rather than re-selecting it.
                  onTeamSelected: (team) => setState(
                    () => _selectedTeam = _selectedTeam == team ? null : team,
                  ),
                ),
              ),

              // Points input form
              if (_selectedTeam != null)
                SliverToBoxAdapter(
                  child: _PointsInputForm(
                    pointsController: _pointsController,
                    reasonController: _reasonController,
                    isSubmitting: _isSubmitting,
                    selectedTeam: teams
                        .where((t) => t.id == _selectedTeam)
                        .firstOrNull,
                    onSubmit: _submitPoints,
                  ),
                ),

              // Points history
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Text(
                    l10n.pointsHistory,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              historyAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (_, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(l10n.somethingWentWrong),
                  ),
                ),
                data: (history) {
                  if (history.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 32,
                        ),
                        child: Center(
                          child: Text(
                            l10n.noPointsHistory,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _AuditHistoryTile(entry: history[index]),
                        childCount: history.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamSelector extends StatelessWidget {
  final List<Team> teams;
  final String? selectedTeam;
  final ValueChanged<String> onTeamSelected;

  const _TeamSelector({
    required this.teams,
    required this.selectedTeam,
    required this.onTeamSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: teams.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final team = teams[index];
          final teamColor = team.color;
          final isSelected = team.id == selectedTeam;

          final teamName = localizedTeamName(l10n, team.name);

          return Semantics(
            button: true,
            selected: isSelected,
            excludeSemantics: true,
            label: '$teamName, ${team.points} ${l10n.pts}',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTeamSelected(team.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? teamColor
                        : teamColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? teamColor
                          : teamColor.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield,
                        color: isSelected
                            ? team.onColor
                            : TeamColors.emphasis(
                                teamColor,
                                Theme.of(context).brightness,
                              ),
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teamName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? team.onColor
                              : TeamColors.emphasis(
                                  teamColor,
                                  Theme.of(context).brightness,
                                ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${team.points} ${l10n.pts}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? team.onColor.withValues(alpha: 0.8)
                              : TeamColors.emphasis(
                                  teamColor,
                                  Theme.of(context).brightness,
                                ).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PointsInputForm extends StatelessWidget {
  final TextEditingController pointsController;
  final TextEditingController reasonController;
  final bool isSubmitting;
  final Team? selectedTeam;
  final VoidCallback onSubmit;

  const _PointsInputForm({
    required this.pointsController,
    required this.reasonController,
    required this.isSubmitting,
    required this.selectedTeam,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final teamColor = selectedTeam?.color ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: teamColor.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: teamColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    selectedTeam != null
                        ? localizedTeamName(l10n, selectedTeam!.name)
                        : '',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Points amount
              TextField(
                controller: pointsController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.pointAmount,
                  hintText: l10n.enterPoints,
                  prefixIcon: const Icon(Icons.add_circle_outline),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.cancel,
                    onPressed: () => pointsController.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  l10n.positiveNegativeHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Quick-amount chips ADD to the current value (+50 twice = 100).
              // Typos are fixed with the field's clear button.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [-150, -100, -50, -25, -10, 10, 25, 50, 100, 150].map((
                  amount,
                ) {
                  final label = amount > 0 ? '+$amount' : '$amount';
                  return ActionChip(
                    label: Text(label),
                    onPressed: () {
                      final current =
                          int.tryParse(pointsController.text.trim()) ?? 0;
                      pointsController.text = '${current + amount}';
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Reason
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.reason,
                  hintText: l10n.reasonHint,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(Icons.edit_note),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Submit button
              FilledButton.icon(
                onPressed: isSubmitting ? null : onSubmit,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(l10n.submitPoints),
                style: FilledButton.styleFrom(
                  backgroundColor: teamColor,
                  foregroundColor: selectedTeam?.onColor ?? Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String locale(BuildContext context) {
    return Localizations.localeOf(context).languageCode;
  }
}

class _AuditHistoryTile extends StatelessWidget {
  final PointsEntry entry;

  const _AuditHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final teamColor = TeamColors.forTeam(
      entry.team,
      entry.teamColorHex,
      entry.teamName,
    );
    final teamName = localizedTeamName(
      l10n,
      entry.teamName.isNotEmpty ? entry.teamName : entry.team,
    );
    final isPositive = entry.amount >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showPointsEntryDetails(
            context,
            entry: entry,
            teamName: teamName,
            teamColor: teamColor,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Team color dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: teamColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),

                // Reason, team, and guide name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.reason.isNotEmpty ? entry.reason : '-',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$teamName · ${entry.addedBy} · ${relativeTime(l10n, entry.timestamp)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Points change: green family for gains, sunset orange for
                // deductions (red stays reserved for emergency UI)
                Builder(
                  builder: (context) {
                    final camp = theme.extension<CampColors>()!;
                    return StatPill(
                      label: '${isPositive ? '+' : ''}${entry.amount}',
                      background: isPositive
                          ? theme.colorScheme.primaryContainer
                          : camp.sunsetSoft,
                      foreground: isPositive
                          ? theme.colorScheme.onPrimaryContainer
                          : camp.onSunsetSoft,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _tvPageUrl = 'https://costincj.github.io/CampConnect/tv/';

/// Shows (and lazily creates, for camps made before this feature) the
/// camp's TV code plus the public page address.
class _TvLeaderboardSheet extends ConsumerStatefulWidget {
  const _TvLeaderboardSheet();

  @override
  ConsumerState<_TvLeaderboardSheet> createState() =>
      _TvLeaderboardSheetState();
}

class _TvLeaderboardSheetState extends ConsumerState<_TvLeaderboardSheet> {
  bool _generating = false;

  Future<void> _ensureTvCode(CampSession session) async {
    if (session.tvCode != null || _generating) return;
    _generating = true;
    try {
      // Read the repository before the awaits below: `ref` itself becomes
      // unsafe to touch once this State is disposed, so anything derived
      // from it has to be grabbed up front, not re-read afterwards.
      final repo = ref.read(campRepositoryProvider);
      final tvCode = await repo.generateUniqueTvCode(orgId: session.orgId);
      await repo.updateCampSession(session.copyWith(tvCode: tvCode));
      // The sheet may have been dismissed while those awaits were in
      // flight (pre-existing camp, slow network); ref.invalidate on a
      // disposed ConsumerState throws, so guard it like _submitPoints does
      // above after its own awaits.
      if (!mounted) return;
      ref.invalidate(activeCampSessionProvider);
    } finally {
      // No mounted guard needed here (unlike _submitPoints's finally,
      // which calls setState): this is a plain field write, not a call
      // that throws on a disposed State.
      _generating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final sessionAsync = ref.watch(activeCampSessionProvider);
    final session = sessionAsync.valueOrNull;

    if (session != null && session.tvCode == null) {
      // Backfill for camps created before TV codes existed.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureTvCode(session));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: session == null || session.tvCode == null
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.tv, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.showOnTv,
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(l10n.tvInstructions,
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    title: Text(_tvPageUrl,
                        style: theme.textTheme.bodyMedium),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                            const ClipboardData(text: _tvPageUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.tvUrlCopied)));
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: ListTile(
                    title: Text(l10n.tvCodeTitle,
                        style: theme.textTheme.labelMedium),
                    subtitle: Text(
                      session.tvCode!,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: session.tvCode!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.tvCodeCopied)));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
