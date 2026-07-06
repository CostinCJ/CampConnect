import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

const _secureStorage = FlutterSecureStorage();

/// Returns the AES encryption key used to encrypt the given user's journal
/// Hive box at rest, generating and persisting a new one (in the Android
/// Keystore / iOS Keychain / platform-equivalent secure storage) on first
/// use.
///
/// The journal content itself always stays in the Hive box; this helper only
/// manages the key material used to encrypt that box.
Future<List<int>> journalEncryptionKey(String uid) async {
  final storageKey = 'journal_hive_key_$uid';
  final existing = await _secureStorage.read(key: storageKey);
  if (existing != null) {
    return existing.split(',').map(int.parse).toList();
  }
  final newKey = Hive.generateSecureKey();
  await _secureStorage.write(key: storageKey, value: newKey.join(','));
  return newKey;
}
