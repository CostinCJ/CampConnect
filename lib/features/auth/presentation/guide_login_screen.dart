import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/core/l10n/localized_validators.dart';
import 'package:camp_connect/features/auth/data/session_auto_select.dart';
import 'package:camp_connect/features/auth/domain/camp_session.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// Maps a lowercased `registerGuide`/guide-sign-in error message (from a
/// [FirebaseAuthException]'s or `registerGuide` [HttpsError]'s `.toString()`)
/// to a user-facing, localized message.
///
/// Extracted as a top-level function (rather than kept private on
/// [_GuideLoginScreenState]) so it's directly unit-testable — see
/// `test/features/auth/friendly_error_test.dart`. This maps only the
/// guide sign-in/registration error vocabulary; `kid_login_screen.dart`'s
/// `claimCampCode` errors are an unrelated domain and are handled separately.
String friendlyGuideAuthError(String errorMessageLowercase, AppL10n l10n) {
  final msg = errorMessageLowercase;
  if (msg.contains('invalid-org-creation-code')) {
    return l10n.invalidOrgCreationCode;
  }
  if (msg.contains('invalid-invite-code')) return l10n.invalidInviteCode;
  if (msg.contains('email-already-in-use')) return l10n.emailAlreadyInUse;
  if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
    return l10n.wrongCredentials;
  }
  if (msg.contains('user-not-found')) return l10n.wrongCredentials;
  if (msg.contains('weak-password')) return l10n.weakPassword;
  if (msg.contains('auth-create-failed')) {
    // Unexpected internal Auth Admin SDK failure (see registerGuide.js) —
    // there's no more specific message to show, but this is an explicit
    // branch rather than an accidental fallthrough.
    return l10n.somethingWentWrong;
  }
  if (msg.contains('too-many-requests') || msg.contains('too-many-attempts')) {
    return l10n.tooManyAttempts;
  }
  if (msg.contains('network')) return l10n.networkError;
  return l10n.somethingWentWrong;
}

/// Which door the user entered through on role selection. Only affects the
/// REGISTER form (which org field shows, titles); sign-in is identical.
enum GuideLoginMode { joinOrg, createOrg }

class GuideLoginScreen extends ConsumerStatefulWidget {
  const GuideLoginScreen({
    super.key,
    this.initialMode = GuideLoginMode.joinOrg,
  });

  final GuideLoginMode initialMode;

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
  final _orgCreationCodeController = TextEditingController();

  late bool _isRegistering;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late bool _isJoiningOrg;

  @override
  void initState() {
    super.initState();
    // "Set up a camp" implies a brand-new organiser -> straight to register.
    // "I'm a guide" is usually a returning user -> sign-in first.
    _isRegistering = widget.initialMode == GuideLoginMode.createOrg;
    _isJoiningOrg = widget.initialMode != GuideLoginMode.createOrg;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _joinOrgCodeController.dispose();
    _newOrgNameController.dispose();
    _orgCreationCodeController.dispose();
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
          joinOrgCode: _isJoiningOrg
              ? _joinOrgCodeController.text.trim()
              : null,
          newOrgName: _isJoiningOrg ? null : _newOrgNameController.text.trim(),
          orgCreationCode: _isJoiningOrg
              ? null
              : _orgCreationCodeController.text.trim(),
        );
      } else {
        await authRepository.signInGuide(email: email, password: password);
      }

      // Refresh user state (needed below and for the router redirect).
      ref.invalidate(appUserProvider);
      final user = await ref.read(appUserProvider.future);

      // New guide in an org with a running session: select it for them
      // instead of dropping them on an empty dashboard.
      CampSession? autoSelected;
      if (user != null) {
        autoSelected = await autoSelectActiveSession(ref, user);
      }
      final effectiveCampId = autoSelected?.id ?? user?.campId;

      // Notification permission + topic subscription are best-effort: a
      // device that can't register for push (e.g. no APNs token) must still
      // be able to sign in. Routing self-heals on next launch (splash).
      try {
        // Asked in-context, after sign-in — never at cold start before login.
        await ref.read(fcmServiceProvider).requestPermission();
        if (effectiveCampId != null) {
          await ref
              .read(fcmServiceProvider)
              .subscribeToTopics(campId: effectiveCampId, role: 'guide');
        }
      } catch (_) {
        // Ignored: push setup failure must not block sign-in.
      }

      if (mounted) {
        context.go('/guide');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppL10n.of(context);
        final message = _friendlyError(e, l10n);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyError(Object e, AppL10n l10n) {
    return friendlyGuideAuthError(e.toString().toLowerCase(), l10n);
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _forgotPassword() async {
    final l10n = AppL10n.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enterEmailForReset)));
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.resetEmailSent)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
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
        title: Text(
          _isRegistering
              ? (_isJoiningOrg ? l10n.joinYourOrg : l10n.setupYourOrg)
              : l10n.guideLogin,
        ),
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
                  Icon(Icons.school, size: 64, color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    _isRegistering
                        ? (_isJoiningOrg ? l10n.joinYourOrg : l10n.setupYourOrg)
                        : l10n.welcomeBack,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegistering ? l10n.signUpSubtitle : l10n.signInSubtitle,
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
                    else ...[
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
                      TextFormField(
                        key: const ValueKey('orgCreationCode'),
                        controller: _orgCreationCodeController,
                        decoration: InputDecoration(
                          labelText: l10n.orgCreationCode,
                          helperText: l10n.orgCreationCodeHelp,
                          prefixIcon: const Icon(Icons.key_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.characters,
                        validator: validators.required,
                        enabled: !_isLoading,
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(
                                () => _isJoiningOrg = !_isJoiningOrg,
                              ),
                        child: Text(
                          _isJoiningOrg
                              ? l10n.switchToCreate
                              : l10n.switchToJoin,
                        ),
                      ),
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
                          setState(() => _obscurePassword = !_obscurePassword);
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
                  if (_isRegistering)
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
                                  '${l10n.byContinuingYouAgreeToPrivacyPolicy} ',
                            ),
                            TextSpan(
                              text: l10n.privacyPolicy,
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                  Uri.parse(AppConstants.privacyPolicyUrl),
                                ),
                            ),
                          ],
                        ),
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
                      _isRegistering ? l10n.hasAccount : l10n.noAccount,
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
