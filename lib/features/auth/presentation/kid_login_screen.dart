import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/constants/app_constants.dart';
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

      // Claim the code server-side (validates + resolves camp atomically).
      final authRepository = ref.read(authRepositoryProvider);
      final claimedUser = await authRepository.signInWithCode(code: code);
      final campId = claimedUser.campId!;

      // Now that the kid is signed in, ask for notification permission
      // in-context (never at cold start before login).
      await ref.read(fcmServiceProvider).requestPermission();

      // Refresh user state, THEN subscribe using the freshly-claimed team so
      // the team-specific points topic is not skipped on a stale null value.
      ref.invalidate(appUserProvider);
      await ref.read(fcmServiceProvider).subscribeToTopics(
            campId: campId,
            role: 'kid',
            team: claimedUser.team,
          );

      if (mounted) {
        context.go('/kid-name');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppL10n.of(context);
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
    final l10n = AppL10n.of(context);
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
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(
                      Icons.child_care,
                      size: 52,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.readyForAdventure,
                    style: theme.textTheme.headlineMedium?.copyWith(
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
                      // Not "CAMP-XXXX": each organiser can set their own
                      // prefix (e.g. "MURES-8F2K"), so the hint only shows
                      // the shape of a code, not a literal example prefix.
                      hintText: 'XXXX-XXXX',
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                    ),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 2,
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
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        children: [
                          TextSpan(
                              text:
                                  '${l10n.byContinuingYouAgreeToPrivacyPolicy} '),
                          TextSpan(
                            text: l10n.privacyPolicy,
                            style: const TextStyle(
                                decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrl(
                                  Uri.parse(AppConstants.privacyPolicyUrl)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: colorScheme.tertiary,
                        foregroundColor: colorScheme.onTertiary,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colorScheme.onTertiary,
                              ),
                            )
                          : Text(
                              l10n.letsGo,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onTertiary,
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
