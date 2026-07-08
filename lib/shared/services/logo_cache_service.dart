import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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
        debugPrint('[LOGO_CACHE] callable returned empty logoUrl, skipping');
        return;
      }

      // Download the image bytes.
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(logoUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint(
          '[LOGO_CACHE] logo download returned HTTP ${response.statusCode}',
        );
        return;
      }

      final chunks = <List<int>>[];
      await for (final chunk in response) {
        chunks.add(chunk);
      }
      final totalLength = chunks.fold<int>(0, (s, c) => s + c.length);
      final bytes = Uint8List(totalLength);
      var offset = 0;
      for (final chunk in chunks) {
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      final file = await _cacheFile();
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('[LOGO_CACHE] cached org logo (${bytes.length} bytes)');
    } catch (e, st) {
      debugPrint('[LOGO_CACHE] fetchAndCache failed (non-fatal): $e\n$st');
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
      debugPrint('[LOGO_CACHE] read failed (non-fatal): $e');
    }
    return null;
  }

  /// Deletes the cached logo file. Call on sign-out / account deletion.
  static Future<void> clearCache() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        await file.delete();
        debugPrint('[LOGO_CACHE] cache cleared');
      }
    } catch (e) {
      debugPrint('[LOGO_CACHE] clearCache failed (non-fatal): $e');
    }
  }
}
