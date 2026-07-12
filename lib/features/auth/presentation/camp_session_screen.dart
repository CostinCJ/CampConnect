import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/core/l10n/localized_team_names.dart';
import 'package:camp_connect/core/theme/team_colors.dart';
import 'package:camp_connect/features/auth/domain/camp_session.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';

class CampSessionScreen extends ConsumerStatefulWidget {
  const CampSessionScreen({super.key});

  @override
  ConsumerState<CampSessionScreen> createState() => _CampSessionScreenState();
}

class _CampSessionScreenState extends ConsumerState<CampSessionScreen> {
  final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(guideCampSessionsProvider);
    final activeCampId = ref.watch(activeCampIdProvider);
    final l10n = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.campSessions)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSessionDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newSession),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(AppL10n.of(context).somethingWentWrong),
            ],
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return EmptyState(
              icon: Icons.calendar_today,
              title: l10n.noSessionsYet,
              message: l10n.tapToCreate,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isActive = session.id == activeCampId;
              final currentUid = ref.watch(appUserProvider).valueOrNull?.uid;
              final canDelete = session.createdBy == currentUid;

              return _SessionCard(
                session: session,
                isActive: isActive,
                canDelete: canDelete,
                dateFormat: _dateFormat,
                onTap: () => _setActiveSession(session),
                onEdit: () => _showEditSessionDialog(session),
                onDelete: () => _deleteSession(session, isActive),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _setActiveSession(CampSession session) async {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;
    final l10n = AppL10n.of(context);

    final previousCampId = ref.read(activeCampIdProvider);
    ref.read(activeCampIdProvider.notifier).select(session.id);

    try {
      await ref
          .read(authRepositoryProvider)
          .updateUserCampId(user.uid, session.id);
    } catch (_) {
      // Persisting the switch failed — roll the selection back so the UI and
      // the profile don't disagree, and surface the failure.
      ref.read(activeCampIdProvider.notifier).select(previousCampId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
      }
      return;
    }

    // Move FCM topic subscriptions to the newly-selected camp so this guide
    // stops receiving the old camp's alerts and starts receiving the new
    // camp's. Best-effort — a failure here must not undo the successful switch.
    try {
      final fcm = ref.read(fcmServiceProvider);
      if (previousCampId != null && previousCampId != session.id) {
        await fcm.unsubscribeFromTopics(previousCampId);
      }
      await fcm.subscribeToTopics(campId: session.id, role: user.role);
    } catch (_) {
      // Ignored: notification routing self-heals on next launch.
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.activeSessionSet}"${session.name}"')),
      );
    }
  }

  Future<void> _deleteSession(CampSession session, bool isSelected) async {
    final l10n = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber,
          color: Theme.of(ctx).colorScheme.error,
          size: 40,
        ),
        title: Text(l10n.deleteSession),
        content: Text(l10n.deleteSessionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(campRepositoryProvider).deleteCamp(session.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
      }
      return;
    }

    // If the deleted session was selected, clear the active camp and stop
    // receiving its notifications.
    if (isSelected) {
      ref.read(activeCampIdProvider.notifier).select(null);
      try {
        await ref.read(fcmServiceProvider).unsubscribeFromTopics(session.id);
      } catch (_) {
        // Ignored: best-effort cleanup.
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.sessionDeleted)));
    }
  }

  void _showCreateSessionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CreateSessionSheet(),
    );
  }

  void _showEditSessionDialog(CampSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditSessionSheet(session: session),
    );
  }
}

/// Edits a camp session's name and dates. Teams are managed separately in the
/// Teams screen (they carry points and codes, so they aren't edited here).
class _EditSessionSheet extends ConsumerStatefulWidget {
  const _EditSessionSheet({required this.session});

  final CampSession session;

  @override
  ConsumerState<_EditSessionSheet> createState() => _EditSessionSheetState();
}

class _EditSessionSheetState extends ConsumerState<_EditSessionSheet> {
  late final TextEditingController _nameController;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.name);
    _startDate = widget.session.startDate;
    _endDate = widget.session.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enterSessionName)));
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.endDateBeforeStart)));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Normalize the end date to the last moment of the chosen day so the
      // final camp day isn't locked out (pickers return midnight).
      final normalizedEnd = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
      );
      await ref
          .read(campRepositoryProvider)
          .updateCampSession(
            widget.session.copyWith(
              name: _nameController.text.trim(),
              startDate: _startDate,
              endDate: normalizedEnd,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.editSession,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.sessionName,
                hintText: l10n.sessionNameHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit),
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                '${l10n.start}: ${DateFormat('d MMM yyyy', locale).format(_startDate)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(
                '${l10n.end}: ${DateFormat('d MMM yyyy', locale).format(_endDate)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: _startDate,
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _endDate = picked);
              },
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.saveChanges),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateSessionSheet extends ConsumerStatefulWidget {
  const _CreateSessionSheet();

  @override
  ConsumerState<_CreateSessionSheet> createState() =>
      _CreateSessionSheetState();
}

class _TeamRow {
  final TextEditingController nameCtrl;
  String colorHex;
  _TeamRow(String name, this.colorHex)
    : nameCtrl = TextEditingController(text: name);
}

class _CreateSessionSheetState extends ConsumerState<_CreateSessionSheet> {
  final _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final List<_TeamRow> _teams = [];
  bool _teamsSeeded = false;
  bool _isCreating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default team names come from l10n, so they follow the app language;
    // l10n needs context, hence seeding here instead of initState.
    if (!_teamsSeeded) {
      _teamsSeeded = true;
      final l10n = AppL10n.of(context);
      final names = [
        l10n.defaultTeamRed,
        l10n.defaultTeamBlue,
        l10n.defaultTeamGreen,
        l10n.defaultTeamYellow,
      ];
      for (var i = 0; i < names.length; i++) {
        _teams.add(_TeamRow(names[i], AppConstants.defaultTeamColorHexes[i]));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final t in _teams) {
      t.nameCtrl.dispose();
    }
    super.dispose();
  }

  /// When the guide picks a colour, refresh the team's name to that colour's
  /// localized name — but only if they haven't typed a custom name yet (the
  /// field is empty or still holds a recognized colour word). A camp that lets
  /// kids choose names just leaves the colour name until it's renamed later.
  void _autoNameForColor(_TeamRow row, String newHex, AppL10n l10n) {
    final current = row.nameCtrl.text.trim();
    final isAutoName =
        current.isEmpty || localizedTeamName(l10n, current) != current;
    final newName = localizedColorNameForHex(l10n, newHex);
    if (isAutoName && newName.isNotEmpty) {
      row.nameCtrl.text = newName;
    }
  }

  Future<Color?> _pickColor(Color initial) async {
    Color selected = initial;
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: initial,
            availableColors: TeamColors.presetHexes
                .map(TeamColors.colorFromHex)
                .toList(),
            onColorChanged: (c) => selected = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: Text(AppL10n.of(ctx).ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.createCampSession,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.sessionName,
                hintText: l10n.sessionNameHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit),
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _startDate != null
                    ? '${l10n.start}: ${DateFormat('d MMM yyyy', Localizations.localeOf(context).toString()).format(_startDate!)}'
                    : l10n.selectStartDate,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _startDate = picked);
                }
              },
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(
                _endDate != null
                    ? '${l10n.end}: ${DateFormat('d MMM yyyy', Localizations.localeOf(context).toString()).format(_endDate!)}'
                    : l10n.selectEndDate,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: _startDate ?? DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _endDate = picked);
                }
              },
            ),
            const SizedBox(height: 16),

            Text(l10n.teams, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._teams.map((row) {
              return Padding(
                key: ObjectKey(row),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: l10n.teamColorLabel,
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () async {
                            final picked = await _pickColor(
                              TeamColors.colorFromHex(row.colorHex),
                            );
                            if (picked != null) {
                              setState(() {
                                final newHex = TeamColors.hexFromColor(picked);
                                _autoNameForColor(row, newHex, l10n);
                                row.colorHex = newHex;
                              });
                            }
                          },
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: TeamColors.colorFromHex(
                                  row.colorHex,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: row.nameCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          hintText: l10n.teamName,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: _teams.length <= 1
                          ? null
                          : () => setState(() {
                              row.nameCtrl.dispose();
                              _teams.remove(row);
                            }),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() {
                // Next free palette color, so a new team never duplicates an
                // existing team's color; named after that color (translatable).
                final hex = TeamColors.firstUnusedPresetHex(
                  _teams.map((t) => t.colorHex),
                  fallbackIndex: _teams.length,
                );
                _teams.add(_TeamRow(localizedColorNameForHex(l10n, hex), hex));
              }),
              icon: const Icon(Icons.add),
              label: Text(l10n.addTeam),
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isCreating
                  ? null
                  : () async {
                      if (_nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.enterSessionName)),
                        );
                        return;
                      }
                      if (_startDate == null || _endDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.selectDates)),
                        );
                        return;
                      }
                      if (_endDate!.isBefore(_startDate!)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.endDateBeforeStart)),
                        );
                        return;
                      }
                      final cleaned = _teams
                          .where((t) => t.nameCtrl.text.trim().isNotEmpty)
                          .map(
                            (t) => (
                              name: t.nameCtrl.text.trim(),
                              colorHex: t.colorHex,
                            ),
                          )
                          .toList();
                      if (cleaned.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.selectAtLeastOneTeam)),
                        );
                        return;
                      }

                      final user = ref.read(appUserProvider).valueOrNull;
                      if (user == null || user.orgId == null) return;

                      setState(() => _isCreating = true);
                      try {
                        final currentLanguage = ref
                            .read(settingsProvider)
                            .language;
                        final orgName =
                            ref
                                .read(currentOrganizationProvider)
                                .valueOrNull
                                ?.name ??
                            '';
                        await ref
                            .read(campRepositoryProvider)
                            .createCampSession(
                              name: _nameController.text.trim(),
                              startDate: _startDate!,
                              endDate: _endDate!,
                              teams: cleaned,
                              createdBy: user.uid,
                              orgId: user.orgId!,
                              orgName: orgName,
                              language: currentLanguage,
                            );

                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      } catch (_) {
                        if (context.mounted) {
                          setState(() => _isCreating = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.somethingWentWrong)),
                          );
                        }
                      }
                    },
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.createSession),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isActive,
    required this.canDelete,
    required this.dateFormat,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final CampSession session;
  final bool isActive;
  final bool canDelete;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Card(
      elevation: isActive ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Selected indicator
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Chip(
                      label: Text(l10n.selected),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                // Session date status
                if (session.hasEnded())
                  Chip(
                    label: Text(l10n.ended),
                    backgroundColor: theme.colorScheme.errorContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                  )
                else if (session.isActive())
                  Chip(
                    label: Text(l10n.inProgress),
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                  tooltip: l10n.editSession,
                  visualDensity: VisualDensity.compact,
                ),
                if (canDelete)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${dateFormat.format(session.startDate)} – ${dateFormat.format(session.endDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.group,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.teamsCount(session.teams.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (!isActive) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(l10n.setActiveSession),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
