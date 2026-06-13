import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/core/theme/team_colors.dart';
import 'package:camp_connect/features/auth/domain/camp_code.dart';

class CodeManagementScreen extends ConsumerStatefulWidget {
  const CodeManagementScreen({super.key});

  @override
  ConsumerState<CodeManagementScreen> createState() => _CodeManagementScreenState();
}

class _CodeManagementScreenState extends ConsumerState<CodeManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final activeCampId = ref.watch(activeCampIdProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (activeCampId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.codeManagement),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noActivecamp,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.selectCampFirst,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final codesAsync = ref.watch(codesForActiveCampProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.codeManagement),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGenerateCodesDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.generateCodes),
      ),
      body: codesAsync.when(
        data: (codes) {
          if (codes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noCodesYet,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tapToGenerate,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group codes by team
          final groupedCodes = <String, List<CampCode>>{};
          for (final code in codes) {
            groupedCodes.putIfAbsent(code.team, () => []).add(code);
          }

          final teamKeys = groupedCodes.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: teamKeys.length,
            itemBuilder: (context, index) {
              final team = teamKeys[index];
              final teamCodes = groupedCodes[team]!;
              final teamColor = TeamColors.getColor(team);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: teamColor.withValues(alpha: 0.15),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: teamColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            TeamColors.localizedName(team, ref.watch(settingsProvider).language),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            l10n.codesCount(teamCodes.length),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Code list
                    ...teamCodes.map((code) => ListTile(
                      leading: Icon(
                        code.used ? Icons.check_circle : Icons.circle_outlined,
                        color: code.used ? Colors.green : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        code.code,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(code.displayName),
                      trailing: code.used
                          ? Chip(
                              label: Text(
                                l10n.used,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                            )
                          : Chip(
                              label: Text(
                                l10n.available,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              backgroundColor: theme.colorScheme.primaryContainer,
                              visualDensity: VisualDensity.compact,
                            ),
                    )),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(l10n.somethingWentWrong),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGenerateCodesDialog(BuildContext screenContext) async {
    final l10n = AppLocalizations.of(screenContext);

    final result = await showDialog<({String team, int count})>(
      context: screenContext,
      builder: (_) => const _GenerateCodesDialog(),
    );

    if (result == null) return;

    final activeCampId = ref.read(activeCampIdProvider);
    if (activeCampId == null) return;

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    await ref.read(campRepositoryProvider).generateBulkCodes(
      campId: activeCampId,
      team: result.team,
      count: result.count,
      createdBy: user.uid,
    );

    if (!screenContext.mounted) return;

    final teamLabel = TeamColors.localizedName(
      result.team,
      ref.read(settingsProvider).language,
    );
    ScaffoldMessenger.of(screenContext).showSnackBar(
      SnackBar(content: Text(l10n.generatedCodesFor(result.count, teamLabel))),
    );
  }
}

class _GenerateCodesDialog extends ConsumerStatefulWidget {
  const _GenerateCodesDialog();

  @override
  ConsumerState<_GenerateCodesDialog> createState() =>
      _GenerateCodesDialogState();
}

class _GenerateCodesDialogState extends ConsumerState<_GenerateCodesDialog> {
  String _selectedTeam = AppConstants.defaultTeams.first;
  final _countController = TextEditingController(text: '5');

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = ref.watch(settingsProvider).language;

    return AlertDialog(
      title: Text(l10n.generateCodes),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.team, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: AppConstants.defaultTeams.map((team) {
              final isSelected = _selectedTeam == team;
              final color = TeamColors.getColor(team);
              return ChoiceChip(
                avatar: CircleAvatar(radius: 8, backgroundColor: color),
                label: Text(TeamColors.localizedName(team, language)),
                selected: isSelected,
                selectedColor: color.withValues(alpha: 0.3),
                onSelected: (_) => setState(() => _selectedTeam = team),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.numberOfCodes,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.tag),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final count = int.tryParse(_countController.text) ?? 5;
            if (count <= 0) return;
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop((team: _selectedTeam, count: count));
          },
          child: Text(l10n.generate),
        ),
      ],
    );
  }
}
