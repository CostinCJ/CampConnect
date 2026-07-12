import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/features/auth/presentation/guide_login_screen.dart'
    show friendlyGuideAuthError;
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/l10n/localized_validators.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// Landing screen for a signed-in guide who belongs to no organisation
/// (typically after being removed by an owner). Offers exactly two exits:
/// join an org with an invite code, or sign out.
class JoinOrganizationScreen extends ConsumerStatefulWidget {
  const JoinOrganizationScreen({super.key});

  @override
  ConsumerState<JoinOrganizationScreen> createState() =>
      _JoinOrganizationScreenState();
}

class _JoinOrganizationScreenState
    extends ConsumerState<JoinOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(organizationRepositoryProvider)
          .joinOrganization(_codeController.text.trim());
      // The callable set new custom claims server-side; without a forced
      // token refresh the cached token keeps the old claims (no orgId) for up
      // to ~1h and every org-scoped read on the guide shell is denied.
      await ref.read(authRepositoryProvider).refreshIdToken();
      ref.invalidate(appUserProvider);
      await ref.read(appUserProvider.future);
      if (mounted) context.go('/guide');
    } catch (e) {
      if (mounted) {
        final l10n = AppL10n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyGuideAuthError(e.toString().toLowerCase(), l10n),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/role-selection');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final validators = LocalizedValidators(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinYourOrg)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.group_add_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.joinYourOrg,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.guideDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: l10n.organizationCode,
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                    ),
                    textInputAction: TextInputAction.done,
                    validator: validators.required,
                    enabled: !_isLoading,
                    onFieldSubmitted: (_) => _join(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _join,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.joinOrganization),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : _signOut,
                    child: Text(l10n.logout),
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
