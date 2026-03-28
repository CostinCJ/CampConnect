import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/core/theme/team_colors.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import '../domain/points_entry.dart';
import '../domain/team.dart';

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

  Future<void> _submitPoints() async {
    final l10n = AppLocalizations.of(context);
    final campId = ref.read(activeCampIdProvider);
    final appUser = ref.read(appUserProvider).valueOrNull;

    if (_selectedTeam == null || campId == null || appUser == null) return;

    final amount = int.tryParse(_pointsController.text.trim());
    if (amount == null || amount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidPointAmount)),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterReason)),
      );
      return;
    }

    // Confirmation dialog
    final teamName = TeamColors.displayName(_selectedTeam!);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmPoints),
        content: Text(l10n.confirmPointsMessage(amount, teamName)),
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
      await ref.read(leaderboardRepositoryProvider).addPoints(
            campId: campId,
            team: _selectedTeam!,
            amount: amount,
            reason: reason,
            addedBy: appUser.displayName,
          );

      if (!mounted) return;

      _pointsController.clear();
      _reasonController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pointsUpdated),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.somethingWentWrong),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(leaderboardProvider);
    final historyAsync = ref.watch(pointsHistoryProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pointsManagement),
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
                  onTeamSelected: (team) =>
                      setState(() => _selectedTeam = team),
                ),
              ),

              // Points input form
              if (_selectedTeam != null)
                SliverToBoxAdapter(
                  child: _PointsInputForm(
                    pointsController: _pointsController,
                    reasonController: _reasonController,
                    isSubmitting: _isSubmitting,
                    selectedTeam: _selectedTeam!,
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
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: teams.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final team = teams[index];
          final teamColor = TeamColors.getColor(team.color);
          final isSelected = team.color == selectedTeam;

          return GestureDetector(
            onTap: () => onTeamSelected(team.color),
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
                        ? TeamColors.getOnColor(team.color)
                        : teamColor,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    team.color[0].toUpperCase() + team.color.substring(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? TeamColors.getOnColor(team.color)
                          : teamColor,
                    ),
                  ),
                  Text(
                    '${team.points} ${l10n.pts}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? TeamColors.getOnColor(team.color)
                              .withValues(alpha: 0.8)
                          : teamColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
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
  final String selectedTeam;
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
    final l10n = AppLocalizations.of(context);
    final teamColor = TeamColors.getColor(selectedTeam);

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
                    TeamColors.displayName(selectedTeam),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  locale(context) == 'hu'
                      ? 'Pozitiv = pontok hozzaadasa, Negativ = pontok levonasa'
                      : 'Pozitiv = adauga puncte, Negativ = scade puncte',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
                  foregroundColor: TeamColors.getOnColor(selectedTeam),
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
    final l10n = AppLocalizations.of(context);
    final teamColor = TeamColors.getColor(entry.team);
    final isPositive = entry.amount >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
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
                      entry.reason.isNotEmpty ? entry.reason : '—',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${TeamColors.displayName(entry.team)} · ${entry.addedBy} · ${l10n.relativeTime(entry.timestamp)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Points change
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${isPositive ? '+' : ''}${entry.amount}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
