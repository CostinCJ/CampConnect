import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/core/l10n/localized_validators.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class KidLoginScreen extends ConsumerStatefulWidget {
  const KidLoginScreen({super.key});

  @override
  ConsumerState<KidLoginScreen> createState() => _KidLoginScreenState();
}

class _KidLoginScreenState extends ConsumerState<KidLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final code = _codeController.text.trim().toUpperCase();

      // Look up the camp by code
      final campRepository = ref.read(campRepositoryProvider);
      final campId = await campRepository.findCampIdByCode(code);

      if (campId == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.invalidCode),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Sign in anonymously with the camp code
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signInWithCode(code: code, campId: campId);

      // Subscribe to FCM topics (including team-specific)
      final loggedInUser = await ref.read(appUserProvider.future);
      await ref.read(fcmServiceProvider).subscribeToTopics(
            campId: campId,
            role: 'kid',
            team: loggedInUser?.team,
          );

      // Refresh user state after auth
      ref.invalidate(appUserProvider);

      if (mounted) {
        context.go('/kid-name');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final msg = e.toString().toLowerCase();
        String message;
        if (msg.contains('invalid-code')) {
          message = l10n.invalidCode;
        } else if (msg.contains('code-used')) {
          message = l10n.codeAlreadyUsed;
        } else if (msg.contains('session-expired')) {
          message = l10n.sessionExpired;
        } else if (msg.contains('network')) {
          message = l10n.networkError;
        } else {
          message = l10n.somethingWentWrong;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final validators = LocalizedValidators(l10n);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/role-selection'),
        ),
        title: Text(l10n.kidLogin),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.child_care,
                      size: 72,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.readyForAdventure,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.enterCampCode,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: l10n.campCode,
                      hintText: 'CAMP-XXXX',
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                    ),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                    ],
                    textInputAction: TextInputAction.done,
                    validator: validators.campCode,
                    enabled: !_isLoading,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.askGuideForCode,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: colorScheme.tertiaryContainer,
                        foregroundColor: colorScheme.onTertiaryContainer,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colorScheme.onTertiaryContainer,
                              ),
                            )
                          : Text(
                              l10n.letsGo,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onTertiaryContainer,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A [TextInputFormatter] that converts all input to uppercase.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
