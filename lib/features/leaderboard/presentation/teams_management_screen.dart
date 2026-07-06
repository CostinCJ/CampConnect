import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/l10n/localized_team_names.dart';
import 'package:camp_connect/core/theme/team_colors.dart';
import 'package:camp_connect/features/leaderboard/data/teams_repository.dart';
import 'package:camp_connect/features/leaderboard/domain/team.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class TeamsManagementScreen extends ConsumerWidget {
  const TeamsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final campId = ref.watch(activeCampIdProvider);
    final teamsAsync = ref.watch(leaderboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.teams)),
      floatingActionButton: campId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showTeamDialog(context, ref, campId, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.addTeam),
            ),
      body: campId == null
          ? Center(child: Text(l10n.noActiveSession))
          : teamsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(l10n.somethingWentWrong)),
              data: (teams) => ListView(
                padding: const EdgeInsets.all(16),
                children: teams
                    .map(
                      (t) => Card(
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: t.color),
                          title: Text(localizedTeamName(l10n, t.name)),
                          subtitle: Text('${t.points} ${l10n.pts}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _showTeamDialog(context, ref, campId, t),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.error,
                                ),
                                onPressed: () => _confirmDelete(
                                  context,
                                  ref,
                                  campId,
                                  t,
                                  teams,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }

  Future<void> _showTeamDialog(
    BuildContext context,
    WidgetRef ref,
    String campId,
    Team? existing,
  ) async {
    final l10n = AppL10n.of(context);
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    // Resolve through Team.color so legacy grey/empty colorHex heals to the
    // derived preset color when the team is saved.
    String colorHex = existing != null
        ? TeamColors.hexFromColor(existing.color)
        : TeamColors.presetHexes.first;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? l10n.addTeam : l10n.editTeam),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.teamName),
              ),
              const SizedBox(height: 16),
              BlockPicker(
                pickerColor: TeamColors.colorFromHex(colorHex),
                availableColors: TeamColors.presetHexes
                    .map(TeamColors.colorFromHex)
                    .toList(),
                onColorChanged: (c) => setDialogState(
                  () => colorHex = TeamColors.hexFromColor(c),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        final repo = ref.read(teamsRepositoryProvider);
                        if (existing == null) {
                          await repo.addTeam(
                            campId,
                            name: nameCtrl.text.trim(),
                            colorHex: colorHex,
                          );
                        } else {
                          await repo.updateTeam(
                            campId,
                            existing.copyWith(
                              name: nameCtrl.text.trim(),
                              colorHex: colorHex,
                            ),
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.somethingWentWrong)),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.ok),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String campId,
    Team team,
    List<Team> allTeams,
  ) async {
    final l10n = AppL10n.of(context);
    // Confirm before ANY delete, even when no kids are affected.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTeamTitle),
        content: Text(l10n.deleteTeamConfirm(team.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(teamsRepositoryProvider).deleteTeam(campId, team.id);
    } on TeamInUseException catch (e) {
      if (!context.mounted) return;
      // Offer reassignment to another team.
      final others = allTeams.where((t) => t.id != team.id).toList();
      if (others.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.cannotDeleteLastTeam)));
        return;
      }
      final target = await showDialog<Team>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.reassignKidsPrompt(e.kidCount)),
          children: others
              .map(
                (t) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, t),
                  child: Text(t.name),
                ),
              )
              .toList(),
        ),
      );
      if (target == null) return;
      await ref
          .read(teamsRepositoryProvider)
          .reassignAndDelete(campId, team.id, target.id);
    }
  }
}
