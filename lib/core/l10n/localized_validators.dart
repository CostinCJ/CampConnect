import 'package:flutter/material.dart';
import 'app_localizations.dart';
import '../constants/app_constants.dart';

class LocalizedValidators {
  final AppLocalizations l10n;

  LocalizedValidators(this.l10n);

  /// Creates a [LocalizedValidators] from the given [BuildContext].
  factory LocalizedValidators.of(BuildContext context) {
    return LocalizedValidators(AppLocalizations.of(context));
  }

  String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return l10n.emailRequired;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return l10n.emailInvalid;
    }
    return null;
  }

  String? password(String? value) {
    if (value == null || value.isEmpty) {
      return l10n.passwordRequired;
    }
    if (value.length < 6) {
      return l10n.passwordTooShort;
    }
    return null;
  }

  String? campCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return l10n.campCodeRequired;
    }
    final code = value.trim().toUpperCase();
    if (!AppConstants.codeRegex.hasMatch(code)) {
      return l10n.campCodeInvalid;
    }
    return null;
  }

  String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return l10n.fieldRequired;
    }
    return null;
  }
}
