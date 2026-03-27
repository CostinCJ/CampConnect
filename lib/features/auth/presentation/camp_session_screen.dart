import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.campSessions),
      ),
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
              Text(AppLocalizations.of(context).somethingWentWrong),
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
                  Text(
                    l10n.noSessionsYet,
                    style: theme.textTheme.titleLarge,
                  ),
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

              return _SessionCard(
                session: session,
                isActive: isActive,
                dateFormat: _dateFormat,
                onTap: () => _setActiveSession(session),
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
    await ref.read(authRepositoryProvider).updateUserCampId(user.uid, session.id);

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.activeSessionSet}"${session.name}"')),
      );
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
  ConsumerState<_CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends ConsumerState<_CreateSessionSheet> {
  final _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  late final Set<String> _selectedTeams;

  @override
  void initState() {
    super.initState();
    _selectedTeams = <String>{...AppConstants.defaultTeams};
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                    ? '${l10n.start}: ${DateFormat('d MMM yyyy').format(_startDate!)}'
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
                    ? '${l10n.end}: ${DateFormat('d MMM yyyy').format(_endDate!)}'
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

            Text(
              l10n.teams,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: AppConstants.defaultTeams.map((team) {
                final isSelected = _selectedTeams.contains(team);
                return FilterChip(
                  label: Text(TeamColors.displayName(team)),
                  selected: isSelected,
                  selectedColor: TeamColors.getColor(team).withValues(alpha: 0.3),
                  checkmarkColor: TeamColors.getColor(team),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTeams.add(team);
                      } else {
                        _selectedTeams.remove(team);
                      }
                    });
                  },
                );
              }).toList(),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.selectDates)),
                  );
                  return;
                }
                if (_selectedTeams.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.selectAtLeastOneTeam)),
                  );
                  return;
                }

                final user = ref.read(appUserProvider).valueOrNull;
                if (user == null) return;

                await ref.read(campRepositoryProvider).createCampSession(
                  name: _nameController.text.trim(),
                  startDate: _startDate!,
                  endDate: _endDate!,
                  teams: _selectedTeams.toList(),
                  createdBy: user.uid,
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
    required this.dateFormat,
    required this.onTap,
  });

  final CampSession session;
  final bool isActive;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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
                  if (isActive)
                    Chip(
                      label: Text(l10n.active),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (session.hasEnded)
                    Chip(
                      label: Text(l10n.ended),
                      backgroundColor: theme.colorScheme.errorContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    )
                  else if (session.isActive && !isActive)
                    Chip(
                      label: Text(l10n.inProgress),
                      backgroundColor: theme.colorScheme.tertiaryContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.date_range, size: 16, color: theme.colorScheme.onSurfaceVariant),
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
                  Icon(Icons.group, size: 16, color: theme.colorScheme.onSurfaceVariant),
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
