import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/utils/relative_time.dart';
import 'package:camp_connect/features/emergency/domain/emergency_alert.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// Guide view: emergency alert history + send new alert button.
class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final alertsAsync = ref.watch(emergencyAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.emergencyHistory),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSendAlertSheet(context, ref),
        backgroundColor: theme.colorScheme.error,
        foregroundColor: theme.colorScheme.onError,
        icon: const Icon(Icons.emergency),
        label: Text(l10n.sendEmergencyAlert),
      ),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.somethingWentWrong)),
        data: (alerts) {
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noEmergencyAlerts,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              return _EmergencyAlertCard(alert: alerts[index]);
            },
          );
        },
      ),
    );
  }

  void _showSendAlertSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SendAlertSheet(),
    );
  }
}

class _EmergencyAlertCard extends ConsumerWidget {
  final EmergencyAlert alert;

  const _EmergencyAlertCard({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final totalGuides = ref.watch(orgMembersProvider).valueOrNull?.length ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emergency, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.emergencyAlertTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  relativeTime(l10n, alert.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alert.message,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.sentBy} ${alert.senderName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (alert.acknowledgedBy.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    totalGuides > 0
                        ? l10n.acknowledgedByCount(
                            alert.acknowledgedBy.length,
                            totalGuides,
                          )
                        : '${l10n.acknowledgedBy}: ${alert.acknowledgedBy.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SendAlertSheet extends ConsumerStatefulWidget {
  const _SendAlertSheet();

  @override
  ConsumerState<_SendAlertSheet> createState() => _SendAlertSheetState();
}

class _SendAlertSheetState extends ConsumerState<_SendAlertSheet> {
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Icon(Icons.emergency, color: theme.colorScheme.error, size: 28),
              const SizedBox(width: 8),
              Text(
                l10n.sendEmergencyAlert,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: l10n.emergencyMessageHint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.tertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.emergencyMessageConfidentialityWarning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _isLoading ? null : _sendAlert,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: theme.colorScheme.onError),
                  )
                : Text(l10n.send),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _sendAlert() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppL10n.of(context).enterEmergencyMessage)),
      );
      return;
    }

    final l10n = AppL10n.of(context);

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber,
            color: Theme.of(context).colorScheme.error, size: 40),
        title: Text(l10n.emergencyConfirm),
        content: Text(l10n.emergencyConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.send),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final campId = ref.read(activeCampIdProvider);
      if (campId == null) return;

      final user = ref.read(appUserProvider).valueOrNull;
      final repo = ref.read(emergencyRepositoryProvider);

      final alert = EmergencyAlert(
        id: '',
        message: message,
        senderId: user?.uid ?? '',
        senderName: user?.displayName ?? '',
        acknowledgedBy: [],
        timestamp: DateTime.now(),
      );

      await repo.createAlert(campId, alert);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.emergencyAlertSent)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppL10n.of(context).somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
