import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/core/l10n/localized_validators.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class GuideLoginScreen extends ConsumerStatefulWidget {
  const GuideLoginScreen({super.key});

  @override
  ConsumerState<GuideLoginScreen> createState() => _GuideLoginScreenState();
}

class _GuideLoginScreenState extends ConsumerState<GuideLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _joinOrgCodeController = TextEditingController();
  final _newOrgNameController = TextEditingController();

  bool _isRegistering = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isJoiningOrg = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _joinOrgCodeController.dispose();
    _newOrgNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isRegistering) {
        final displayName = _displayNameController.text.trim();
        await authRepository.registerGuide(
          email: email,
          password: password,
          displayName: displayName,
          joinOrgCode: _isJoiningOrg ? _joinOrgCodeController.text.trim() : null,
          newOrgName: _isJoiningOrg ? null : _newOrgNameController.text.trim(),
        );
      } else {
        await authRepository.signInGuide(email: email, password: password);
      }

      // Refresh user state and get the user to subscribe to FCM
      ref.invalidate(appUserProvider);

      // Wait for user data to subscribe to FCM topics
      final user = await ref.read(appUserProvider.future);
      if (user?.campId != null) {
        await ref.read(fcmServiceProvider).subscribeToTopics(
              campId: user!.campId!,
              role: 'guide',
            );
      }

      if (mounted) {
        context.go('/guide');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final message = _friendlyError(e, l10n);
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

  String _friendlyError(Object e, AppLocalizations l10n) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid-invite-code')) return l10n.invalidInviteCode;
    if (msg.contains('email-already-in-use')) return l10n.emailAlreadyInUse;
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return l10n.wrongCredentials;
    }
    if (msg.contains('user-not-found')) return l10n.wrongCredentials;
    if (msg.contains('too-many-requests')) return l10n.tooManyAttempts;
    if (msg.contains('network')) return l10n.networkError;
    return l10n.somethingWentWrong;
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _forgotPassword() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterEmailForReset)),
      );
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.resetEmailSent)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.somethingWentWrong)),
        );
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
        title: Text(_isRegistering ? l10n.createAccount : l10n.guideLogin),
      ),
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
                    Icons.school,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRegistering ? l10n.createAccount : l10n.welcomeBack,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegistering
                        ? l10n.signUpSubtitle
                        : l10n.signInSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_isRegistering) ...[
                    TextFormField(
                      controller: _displayNameController,
                      decoration: InputDecoration(
                        labelText: l10n.displayName,
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      validator: validators.required,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text(l10n.joinOrganization),
                          icon: const Icon(Icons.group_add_outlined),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text(l10n.createOrganization),
                          icon: const Icon(Icons.add_business_outlined),
                        ),
                      ],
                      selected: {_isJoiningOrg},
                      onSelectionChanged: _isLoading
                          ? null
                          : (selected) {
                              setState(() => _isJoiningOrg = selected.first);
                            },
                    ),
                    const SizedBox(height: 16),
                    if (_isJoiningOrg)
                      TextFormField(
                        key: const ValueKey('joinOrgCode'),
                        controller: _joinOrgCodeController,
                        decoration: InputDecoration(
                          labelText: l10n.organizationCode,
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: validators.required,
                        enabled: !_isLoading,
                      )
                    else
                      TextFormField(
                        key: const ValueKey('newOrgName'),
                        controller: _newOrgNameController,
                        decoration: InputDecoration(
                          labelText: l10n.organizationName,
                          prefixIcon: const Icon(Icons.business_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        validator: validators.required,
                        enabled: !_isLoading,
                      ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: validators.email,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(
                              () => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    validator: validators.password,
                    enabled: !_isLoading,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (!_isRegistering)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        child: Text(l10n.forgotPassword),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isRegistering ? l10n.createAccount : l10n.signIn,
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : _toggleMode,
                    child: Text(
                      _isRegistering
                          ? l10n.hasAccount
                          : l10n.noAccount,
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
