import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/core/theme/team_colors.dart';
import 'package:camp_connect/features/auth/domain/camp_session.dart';

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
    final theme = Theme.of(context);
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.noSessionsYet, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tapToCreate,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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

    ref.read(activeCampIdProvider.notifier).state = session.id;
    await ref
        .read(authRepositoryProvider)
        .updateUserCampId(user.uid, session.id);

    if (mounted) {
      final l10n = AppL10n.of(context);
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
        icon: const Icon(Icons.warning_amber, color: Colors.red, size: 40),
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

    await ref.read(campRepositoryProvider).deleteCampSession(session.id);

    // If the deleted session was selected, clear the active camp
    if (isSelected) {
      ref.read(activeCampIdProvider.notifier).state = null;
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
                    GestureDetector(
                      onTap: () async {
                        final picked = await _pickColor(
                          TeamColors.colorFromHex(row.colorHex),
                        );
                        if (picked != null) {
                          setState(
                            () =>
                                row.colorHex = TeamColors.hexFromColor(picked),
                          );
                        }
                      },
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: TeamColors.colorFromHex(row.colorHex),
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
              onPressed: () => setState(
                () => _teams.add(_TeamRow('', TeamColors.presetHexes.first)),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.addTeam),
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: () async {
                if (_nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.enterSessionName)),
                  );
                  return;
                }
                if (_startDate == null || _endDate == null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.selectDates)));
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
                      (t) =>
                          (name: t.nameCtrl.text.trim(), colorHex: t.colorHex),
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

                final currentLanguage = ref.read(settingsProvider).language;
                await ref
                    .read(campRepositoryProvider)
                    .createCampSession(
                      name: _nameController.text.trim(),
                      startDate: _startDate!,
                      endDate: _endDate!,
                      teams: cleaned,
                      createdBy: user.uid,
                      orgId: user.orgId!,
                      language: currentLanguage,
                    );

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(l10n.createSession),
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
    required this.onDelete,
  });

  final CampSession session;
  final bool isActive;
  final bool canDelete;
  final DateFormat dateFormat;
  final VoidCallback onTap;
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
            ],
          ),
        ),
      ),
    );
  }
}
