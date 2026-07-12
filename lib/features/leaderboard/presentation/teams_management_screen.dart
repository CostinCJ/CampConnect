import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/l10n/localized_team_names.dart';
import 'package:camp_connect/core/theme/team_colors.dart';
import 'package:camp_connect/features/leaderboard/data/teams_repository.dart';
import 'package:camp_connect/features/leaderboard/domain/team.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';

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
          ? EmptyState(icon: Icons.event_busy, title: l10n.noActiveSession)
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
                                  color: theme.colorScheme.onSurfaceVariant,
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
    // Next free palette color, so a NEW team never defaults to a color
    // another team already has.
    final existingHexes = (ref.read(leaderboardProvider).valueOrNull ?? [])
        .map((t) => TeamColors.hexFromColor(t.color));
    final defaultHex = TeamColors.firstUnusedPresetHex(existingHexes);
    // New teams start named after their default colour (translatable); the
    // guide can rename later — e.g. to a name the kids chose — without the
    // colour changing. Existing names go through localizedTeamName so a team
    // stored as "Roșu" edits as "Red"/"Piros" in the current app language
    // (custom names pass through untouched) — which also keeps the auto-name
    // check below language-independent.
    final nameCtrl = TextEditingController(
      text: existing != null
          ? localizedTeamName(l10n, existing.name)
          : localizedColorNameForHex(l10n, defaultHex),
    );
    // Resolve through Team.color so legacy grey/empty colorHex heals to the
    // derived preset color when the team is saved.
    String colorHex = existing != null
        ? TeamColors.hexFromColor(existing.color)
        : defaultHex;
    // Whether the name still tracks the chosen colour (so picking a new colour
    // renames it) or the guide has typed their own name (so the colour changes
    // without touching the name). A new team starts auto; an existing team is
    // auto only while its name is still exactly its colour's localized name.
    bool nameIsAuto = existing == null ||
        nameCtrl.text.trim() == localizedColorNameForHex(l10n, colorHex);
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
                // A manual edit means the guide wants their own name; stop
                // auto-renaming when the colour changes. (Programmatic writes
                // to nameCtrl.text below do NOT fire onChanged.)
                onChanged: (_) => nameIsAuto = false,
              ),
              const SizedBox(height: 16),
              BlockPicker(
                pickerColor: TeamColors.colorFromHex(colorHex),
                availableColors: TeamColors.presetHexes
                    .map(TeamColors.colorFromHex)
                    .toList(),
                onColorChanged: (c) => setDialogState(() {
                  final newHex = TeamColors.hexFromColor(c);
                  // While the name still tracks the colour, follow the new
                  // colour's localized name; a custom name is left untouched.
                  if (nameIsAuto) {
                    final newName = localizedColorNameForHex(l10n, newHex);
                    if (newName.isNotEmpty) nameCtrl.text = newName;
                  }
                  colorHex = newHex;
                }),
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
            style: destructiveFilledStyle(Theme.of(ctx)),
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
