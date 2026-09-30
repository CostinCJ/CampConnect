import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';

import 'package:camp_connect/core/utils/debug_log.dart';

import '../../core/constants/app_constants.dart';

/// Eagerly caches the organisation logo on the device so that the journal PDF
/// export works even without network (kids may be in the field with no signal).
///
/// Usage:
/// - Call [fetchAndCache] right after a successful kid login (fire-and-forget).
/// - Call [getCachedLogoBytes] in the PDF export to read the cached file.
/// - Call [clearCache] on sign-out so a stale logo doesn't leak across orgs.
class LogoCacheService {
  LogoCacheService._();

  static const _fileName = 'org_logo_cache.jpg';

  /// Returns the local file path used for the cached logo.
  static Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Calls the `getOrganizationLogoUrl` callable, downloads the image, and
  /// writes it to local storage. Intended to be fired-and-forgotten — any
  /// failure is silently swallowed (logo is cosmetic, never critical).
  static Future<void> fetchAndCache() async {
    try {
      final functions = FirebaseFunctions.instanceFor(
        region: AppConstants.functionsRegion,
      );
      final result = await functions
          .httpsCallable('getOrganizationLogoUrl')
          .call();
      final logoUrl = result.data['logoUrl'] as String? ?? '';
      if (logoUrl.isEmpty) {
        debugLog('[LOGO_CACHE] callable returned empty logoUrl, skipping');
        return;
      }

      final bytes = await downloadLogo(logoUrl);
      if (bytes == null) return;

      final file = await _cacheFile();
      await file.writeAsBytes(bytes, flush: true);
      debugLog('[LOGO_CACHE] cached org logo (${bytes.length} bytes)');
    } catch (e, st) {
      debugLog('[LOGO_CACHE] fetchAndCache failed (non-fatal): $e\n$st');
    }
  }

  /// Largest logo accepted. Storage rules cap uploads at 10 MB, but the app
  /// compresses logos to well under 1 MB, so anything bigger is not ours.
  static const int maxLogoBytes = 5 * 1024 * 1024;

  /// Downloads a logo from a Firebase Storage download URL. Returns null for
  /// any other host (the org's `logoUrl` is owner-editable, so it must not
  /// make every kid's device fetch arbitrary URLs), a non-200 response, or a
  /// body larger than [maxLogoBytes].
  static Future<Uint8List?> downloadLogo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'firebasestorage.googleapis.com') {
      debugLog('[LOGO_CACHE] refusing non-Storage logo URL');
      return null;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final response = await (await client.getUrl(uri)).close();
      if (response.statusCode != 200 ||
          response.contentLength > maxLogoBytes) {
        debugLog('[LOGO_CACHE] logo download rejected '
            '(HTTP ${response.statusCode}, ${response.contentLength} bytes)');
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > maxLogoBytes) {
          debugLog('[LOGO_CACHE] logo exceeded $maxLogoBytes bytes, aborting');
          return null;
        }
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  /// Returns the cached logo bytes, or `null` if no cache exists.
  static Future<Uint8List?> getCachedLogoBytes() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugLog('[LOGO_CACHE] read failed (non-fatal): $e');
    }
    return null;
  }

  /// Deletes the cached logo file. Call on sign-out / account deletion.
  static Future<void> clearCache() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        await file.delete();
        debugLog('[LOGO_CACHE] cache cleared');
      }
    } catch (e) {
      debugLog('[LOGO_CACHE] clearCache failed (non-fatal): $e');
    }
  }
}
