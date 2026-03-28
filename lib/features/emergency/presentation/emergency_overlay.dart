import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/emergency/domain/emergency_alert.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// Tracks the last acknowledged alert ID to avoid re-showing alerts.
final _lastAcknowledgedAlertIdProvider = StateProvider<String?>((ref) => null);

/// Widget that listens for new emergency alerts and shows a full-screen overlay.
/// Place this in the guide navigation shell so it's always active.
class EmergencyAlertListener extends ConsumerWidget {
  final Widget child;

  const EmergencyAlertListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<List<EmergencyAlert>>>(
      emergencyAlertsProvider,
      (previous, next) {
        final alerts = next.valueOrNull;
        if (alerts == null || alerts.isEmpty) return;

        final currentUser = ref.read(appUserProvider).valueOrNull;
        if (currentUser == null) return;

        final lastAcked = ref.read(_lastAcknowledgedAlertIdProvider);

        // Find the newest alert that hasn't been acknowledged by this user
        final unackedAlert = alerts.firstOrNull;
        if (unackedAlert == null) return;
        if (unackedAlert.isAcknowledgedBy(currentUser.uid)) return;
        if (unackedAlert.senderId == currentUser.uid) return;
        if (unackedAlert.id == lastAcked) return;

        // Show the overlay
        _showEmergencyOverlay(context, ref, unackedAlert);
      },
    );

    return child;
  }

  void _showEmergencyOverlay(
      BuildContext context, WidgetRef ref, EmergencyAlert alert) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _EmergencyOverlayDialog(alert: alert),
    );
  }
}

class _EmergencyOverlayDialog extends ConsumerStatefulWidget {
  final EmergencyAlert alert;

  const _EmergencyOverlayDialog({required this.alert});

  @override
  ConsumerState<_EmergencyOverlayDialog> createState() =>
      _EmergencyOverlayDialogState();
}

class _EmergencyOverlayDialogState
    extends ConsumerState<_EmergencyOverlayDialog> {
  bool _isAcknowledging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      child: Dialog.fullscreen(
        backgroundColor: Colors.red.shade900,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.emergency,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.emergencyOverlayTitle,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.alert.message,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${l10n.sentBy} ${widget.alert.senderName}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.relativeTime(widget.alert.timestamp),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isAcknowledging ? null : _acknowledge,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    icon: _isAcknowledging
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red.shade900,
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(l10n.acknowledge),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _acknowledge() async {
    setState(() => _isAcknowledging = true);

    try {
      final campId = ref.read(activeCampIdProvider);
      final user = ref.read(appUserProvider).valueOrNull;
      if (campId == null || user == null) return;

      await ref
          .read(emergencyRepositoryProvider)
          .acknowledgeAlert(campId, widget.alert.id, user.uid);

      // Track that we acknowledged this alert
      ref.read(_lastAcknowledgedAlertIdProvider.notifier).state =
          widget.alert.id;

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAcknowledging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).somethingWentWrong)),
        );
      }
    }
  }
}
